import 'dart:async';
import 'dart:convert';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../repositories/media_job_store.dart';
import 'media_extractor.dart';

class DownloadManager extends ChangeNotifier {
  DownloadManager({
    FileDownloader? downloader,
    SharedPreferencesAsync? preferences,
    YtDlpBridge mediaBridge = const YtDlpBridge(),
    MediaJobStore? mediaJobStore,
  })  : _downloaderInstance = downloader,
        _preferencesInstance = preferences,
        _mediaBridge = mediaBridge,
        _mediaJobStore = mediaJobStore ?? MediaJobStore();

  static const _prefTheme = 'theme_mode';
  static const _prefSimultaneous = 'simultaneous_downloads';
  static const _prefAutoRetry = 'auto_retry';
  static const _prefWifiOnly = 'wifi_only';
  static const _prefDirectory = 'download_directory';
  static const _prefMediaEnabled = 'media_extraction_enabled';
  static const _prefUseAria2 = 'media_use_aria2';
  static const _prefQuality = 'media_preferred_quality';
  static const _prefMediaJobs = 'media_jobs_v1';

  FileDownloader? _downloaderInstance;
  SharedPreferencesAsync? _preferencesInstance;
  StreamSubscription<TaskUpdate>? _updatesSubscription;
  StreamSubscription<TaskRecord>? _databaseSubscription;
  StreamSubscription<String>? _shareSubscription;
  Timer? _mediaPollTimer;

  final YtDlpBridge _mediaBridge;
  final MediaJobStore _mediaJobStore;
  final Map<String, TransferTelemetry> _telemetry = {};
  List<TaskRecord> _records = const [];
  List<MediaJob> _mediaJobs = const [];

  bool _initialized = false;
  String? _initializationError;
  int _simultaneousDownloads = 3;
  bool _autoRetry = true;
  bool _wifiOnly = false;
  String _downloadDirectory = 'Downloads';
  ThemeMode _themeMode = ThemeMode.system;
  bool _mediaExtractionEnabled = true;
  bool _useAria2 = true;
  int _preferredQuality = 1080;
  String? _pendingSharedUrl;

  FileDownloader get _downloader =>
      _downloaderInstance ??= FileDownloader();
  SharedPreferencesAsync get _preferences =>
      _preferencesInstance ??= SharedPreferencesAsync();

  bool get initialized => _initialized;
  String? get initializationError => _initializationError;
  List<TaskRecord> get records => List.unmodifiable(_records);
  List<MediaJob> get mediaJobs => List.unmodifiable(_mediaJobs);
  int get simultaneousDownloads => _simultaneousDownloads;
  bool get autoRetry => _autoRetry;
  bool get wifiOnly => _wifiOnly;
  String get downloadDirectory => _downloadDirectory;
  ThemeMode get themeMode => _themeMode;
  bool get mediaExtractionEnabled => _mediaExtractionEnabled;
  bool get useAria2 => _useAria2;
  int get preferredQuality => _preferredQuality;
  String? get pendingSharedUrl => _pendingSharedUrl;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _loadPreferences();
      await _loadMediaJobs();

      _updatesSubscription = _downloader.updates.listen(_onTaskUpdate);
      _downloader.configureNotification(
        running: const TaskNotification(
          'Downloading',
          '{filename} • {progress} • {networkSpeed}',
        ),
        complete: const TaskNotification('Download complete', '{filename}'),
        error: const TaskNotification('Download failed', '{filename}'),
        paused: const TaskNotification('Download paused', '{filename}'),
        canceled: const TaskNotification('Download canceled', '{filename}'),
        progressBar: true,
        tapOpensFile: true,
      );

      await _downloader.start(autoCleanDatabase: false);
      _databaseSubscription = _downloader.database.updates.listen((_) {
        unawaited(refreshRecords());
      });
      await _downloader.resumeFromBackground();
      await _applyConcurrency();
      await refreshRecords(notify: false);

      if (_mediaExtractionEnabled) {
        _startShareListener();
        await refreshMediaJobs(notify: false);
      }
    } catch (error) {
      _initializationError = error.toString();
    } finally {
      _initialized = true;
      _ensureMediaPolling();
      notifyListeners();
    }
  }

  Future<void> _loadPreferences() async {
    _simultaneousDownloads =
        (await _preferences.getInt(_prefSimultaneous) ?? 3).clamp(1, 9).toInt();
    _autoRetry = await _preferences.getBool(_prefAutoRetry) ?? true;
    _wifiOnly = await _preferences.getBool(_prefWifiOnly) ?? false;
    _downloadDirectory = _normalizeDirectory(
      await _preferences.getString(_prefDirectory) ?? 'Downloads',
    );
    _mediaExtractionEnabled =
        await _preferences.getBool(_prefMediaEnabled) ?? true;
    _useAria2 = await _preferences.getBool(_prefUseAria2) ?? true;
    _preferredQuality =
        (await _preferences.getInt(_prefQuality) ?? 1080).clamp(0, 4320).toInt();

    final storedTheme = await _preferences.getString(_prefTheme);
    _themeMode = switch (storedTheme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> _loadMediaJobs() async {
    _mediaJobs = await _mediaJobStore.loadAll();
    if (_mediaJobs.isNotEmpty) return;

    final stored = await _preferences.getString(_prefMediaJobs);
    if (stored == null || stored.isEmpty) return;
    try {
      final values = jsonDecode(stored);
      if (values is List) {
        _mediaJobs = values
            .whereType<String>()
            .map(MediaJob.fromJson)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await _mediaJobStore.upsertAll(_mediaJobs);
        await _preferences.remove(_prefMediaJobs);
      }
    } catch (_) {
      _mediaJobs = const [];
    }
  }

  Future<void> _saveMediaJobs() async {
    await _mediaJobStore.upsertAll(_mediaJobs);
  }

  void _startShareListener() {
    if (_shareSubscription != null) return;
    _shareSubscription = _mediaBridge.sharedUrls.listen(
      (value) {
        _pendingSharedUrl = value.trim();
        notifyListeners();
      },
      onError: (_) {},
    );
  }

  String? consumePendingSharedUrl() {
    final value = _pendingSharedUrl;
    _pendingSharedUrl = null;
    return value;
  }

  Future<void> refreshAll() async {
    await Future.wait([
      refreshRecords(notify: false),
      if (_mediaExtractionEnabled) refreshMediaJobs(notify: false),
    ]);
    notifyListeners();
  }

  Future<void> refreshRecords({bool notify = true}) async {
    final records = await _downloader.database.allRecords();
    records.sort(
      (a, b) => b.task.creationTime.compareTo(a.task.creationTime),
    );
    _records = records;
    if (notify) notifyListeners();
  }

  void _onTaskUpdate(TaskUpdate update) {
    final taskId = update.task.taskId;
    if (update is TaskProgressUpdate) {
      _telemetry[taskId] = TransferTelemetry(
        progress: update.progress,
        expectedFileSize:
            update.hasExpectedFileSize ? update.expectedFileSize : null,
        networkSpeed: update.hasNetworkSpeed ? update.networkSpeed : null,
        timeRemaining: update.hasTimeRemaining ? update.timeRemaining : null,
      );
      notifyListeners();
    } else if (update is TaskStatusUpdate) {
      if (update.status.isFinalState) {
        _telemetry.remove(taskId);
      }
      unawaited(refreshRecords());
    }
  }

  TransferTelemetry? telemetryFor(String taskId) => _telemetry[taskId];

  double progressFor(TaskRecord record) {
    if (record.status == TaskStatus.complete) return 1;
    final live = _telemetry[record.task.taskId]?.progress;
    final value = live != null && live >= 0 ? live : record.progress;
    if (value < 0) return 0;
    return value.clamp(0.0, 1.0).toDouble();
  }

  int? expectedSizeFor(TaskRecord record) {
    final live = _telemetry[record.task.taskId]?.expectedFileSize;
    if (live != null && live > 0) return live;
    return record.expectedFileSize > 0 ? record.expectedFileSize : null;
  }

  Future<LinkInspection> inspectLink(String value) async {
    final input = value.trim();
    final uri = Uri.tryParse(input);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty) {
      throw const FormatException('Enter a valid HTTP or HTTPS URL.');
    }

    if (_looksLikeDirectFile(uri)) {
      try {
        return LinkInspection.direct(await inspectUrl(input));
      } catch (_) {
        if (!_mediaExtractionEnabled) rethrow;
      }
    }

    if (_mediaExtractionEnabled) {
      try {
        final media = await _mediaBridge.inspect(input);
        return LinkInspection.media(media);
      } catch (mediaError) {
        try {
          return LinkInspection.direct(await inspectUrl(input));
        } catch (_) {
          throw StateError(_friendlyMediaError(mediaError));
        }
      }
    }

    return LinkInspection.direct(await inspectUrl(input));
  }

  Future<RemoteFileInfo> inspectUrl(String value) async {
    final input = value.trim();
    final uri = Uri.tryParse(input);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty) {
      throw const FormatException(
        'Enter a valid direct HTTP or HTTPS file URL.',
      );
    }

    final client = http.Client();
    try {
      final request = http.Request('HEAD', uri)
        ..headers['User-Agent'] = 'DownloadVideoApp/1.2';
      var response = await client
          .send(request)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 405 || response.statusCode == 403) {
        final fallback = http.Request('GET', uri)
          ..headers['User-Agent'] = 'DownloadVideoApp/1.2'
          ..headers['Range'] = 'bytes=0-0';
        response = await client
            .send(fallback)
            .timeout(const Duration(seconds: 15));
      }

      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw StateError(
          'The server rejected the link (HTTP ${response.statusCode}).',
        );
      }

      final disposition = response.headers['content-disposition'];
      final headerName = _filenameFromDisposition(disposition);
      final pathName = uri.pathSegments.isEmpty
          ? null
          : Uri.decodeComponent(uri.pathSegments.last);
      final mimeType = response.headers['content-type']?.split(';').first.trim();
      if ((mimeType == 'text/html' || mimeType == 'application/xhtml+xml') &&
          !_looksLikeDirectFile(uri)) {
        throw StateError('This is a web page, not a direct file URL.');
      }

      final fileName = _sanitizeFileName(
        headerName?.isNotEmpty == true
            ? headerName!
            : (pathName?.isNotEmpty == true
                  ? pathName!
                  : 'download_${DateTime.now().millisecondsSinceEpoch}.bin'),
      );

      final contentRangeSize = _sizeFromContentRange(
        response.headers['content-range'],
      );
      return RemoteFileInfo(
        url: uri.toString(),
        fileName: fileName,
        host: uri.host,
        supportsResume:
            response.headers['accept-ranges']?.toLowerCase().contains('bytes') ??
            response.statusCode == 206,
        sizeBytes: contentRangeSize ??
            (response.contentLength != null && response.contentLength! > 0
                ? response.contentLength
                : null),
        mimeType: mimeType,
      );
    } on TimeoutException {
      throw StateError('The server did not respond in time.');
    } finally {
      client.close();
    }
  }

  Future<DownloadTask> startDownload(
    RemoteFileInfo info, {
    bool? wifiOnly,
  }) async {
    final task = DownloadTask(
      url: info.url,
      filename: _sanitizeFileName(info.fileName),
      directory: _downloadDirectory,
      baseDirectory: BaseDirectory.applicationSupport,
      updates: Updates.statusAndProgress,
      requiresWiFi: wifiOnly ?? _wifiOnly,
      retries: _autoRetry ? 5 : 0,
      allowPause: true,
      displayName: info.fileName,
      metaData: info.mimeType ?? '',
    );

    final enqueued = await _downloader.enqueue(task);
    if (!enqueued) {
      throw StateError('The download could not be added to the queue.');
    }
    await refreshRecords();
    return task;
  }

  Future<MediaJob> startMediaDownload(
    MediaInfo info, {
    required String formatSelector,
    required String formatLabel,
    String? audioFormat,
    bool playlist = false,
    bool? wifiOnly,
  }) async {
    if (!_mediaExtractionEnabled) {
      throw StateError('Media extraction is disabled in Settings.');
    }
    final effectiveWifi = wifiOnly ?? _wifiOnly;
    final id = await _mediaBridge.enqueue(
      url: info.url,
      title: info.title,
      formatSelector: formatSelector,
      formatLabel: formatLabel,
      wifiOnly: effectiveWifi,
      useAria2: _useAria2,
      playlist: playlist,
      audioFormat: audioFormat,
    );
    final job = MediaJob(
      id: id,
      url: info.url,
      title: info.title,
      formatLabel: formatLabel,
      formatSelector: formatSelector,
      audioFormat: audioFormat,
      thumbnail: info.thumbnail,
      createdAt: DateTime.now(),
      state: MediaJobState.queued,
      progress: 0,
      playlist: playlist,
      wifiOnly: effectiveWifi,
      useAria2: _useAria2,
    );
    _mediaJobs = [job, ..._mediaJobs];
    await _mediaJobStore.upsert(job);
    _ensureMediaPolling();
    notifyListeners();
    return job;
  }

  Future<void> refreshMediaJobs({bool notify = true}) async {
    if (_mediaJobs.isEmpty) return;
    try {
      final states = await _mediaBridge.jobStates(
        _mediaJobs.map((e) => e.id).toList(),
      );
      final byId = <String, Map<Object?, Object?>>{
        for (final item in states)
          if (item['id'] != null) item['id'].toString(): item,
      };
      var changed = false;
      _mediaJobs = _mediaJobs.map((job) {
        final state = byId[job.id];
        if (state == null) return job;
        final next = job.copyWith(
          state: _mediaStateFromName(state['state']?.toString()),
          progress: (state['progress'] as num?)?.toInt(),
          etaSeconds: (state['eta'] as num?)?.toInt(),
          outputPath: state['outputPath']?.toString(),
          error: state['error']?.toString(),
          sizeBytes: (state['sizeBytes'] as num?)?.toInt(),
        );
        if (next.state != job.state ||
            next.progress != job.progress ||
            next.outputPath != job.outputPath ||
            next.error != job.error) {
          changed = true;
        }
        return next;
      }).toList();
      if (changed) await _saveMediaJobs();
    } catch (_) {
      // The native media engine is Android-only; direct downloads remain usable.
    }
    _ensureMediaPolling();
    if (notify) notifyListeners();
  }

  void _ensureMediaPolling() {
    final shouldPoll = _mediaExtractionEnabled && _mediaJobs.any((e) => e.isActive);
    if (!shouldPoll) {
      _mediaPollTimer?.cancel();
      _mediaPollTimer = null;
      return;
    }
    _mediaPollTimer ??= Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(refreshMediaJobs());
    });
  }

  Future<bool> cancelMediaJob(MediaJob job) async {
    final canceled = await _mediaBridge.cancel(job.id);
    await refreshMediaJobs();
    return canceled;
  }

  Future<MediaJob> retryMediaJob(MediaJob job) async {
    final id = await _mediaBridge.enqueue(
      url: job.url,
      title: job.title,
      formatSelector: job.formatSelector,
      formatLabel: job.formatLabel,
      wifiOnly: job.wifiOnly,
      useAria2: job.useAria2,
      playlist: job.playlist,
      audioFormat: job.audioFormat,
    );
    final retried = job.copyWith(
      id: id,
      state: MediaJobState.queued,
      progress: 0,
      etaSeconds: 0,
      outputPath: '',
      error: '',
      sizeBytes: 0,
    );
    _mediaJobs = [retried, ..._mediaJobs];
    await _mediaJobStore.upsert(retried);
    _ensureMediaPolling();
    notifyListeners();
    return retried;
  }

  Future<bool> openMediaJob(MediaJob job) async {
    final path = job.outputPath;
    if (job.state != MediaJobState.succeeded || path == null || path.isEmpty) {
      return false;
    }
    return _mediaBridge.openPath(path);
  }

  Future<bool> shareMediaJob(MediaJob job) async {
    final path = job.outputPath;
    if (job.state != MediaJobState.succeeded || path == null || path.isEmpty) {
      return false;
    }
    return _mediaBridge.sharePath(path);
  }

  Future<void> deleteMediaHistory(MediaJob job) async {
    if (job.isActive) await _mediaBridge.cancel(job.id);
    _mediaJobs = _mediaJobs.where((e) => e.id != job.id).toList();
    await _mediaJobStore.delete(job.id);
    _ensureMediaPolling();
    notifyListeners();
  }

  Future<bool> pause(TaskRecord record) async {
    final task = record.task;
    if (task is! DownloadTask) return false;
    return _downloader.pause(task);
  }

  Future<bool> resume(TaskRecord record) async {
    final task = record.task;
    if (task is! DownloadTask) return false;
    return _downloader.resume(task);
  }

  Future<bool> cancel(TaskRecord record) =>
      _downloader.cancelTaskWithId(record.task.taskId);

  Future<bool> retry(TaskRecord record) async {
    final oldTask = record.task;
    if (oldTask is! DownloadTask) return false;
    if (record.status == TaskStatus.paused) return resume(record);

    final task = DownloadTask(
      url: oldTask.url,
      filename: oldTask.filename,
      headers: oldTask.headers,
      directory: oldTask.directory,
      baseDirectory: oldTask.baseDirectory,
      updates: Updates.statusAndProgress,
      requiresWiFi: _wifiOnly || oldTask.requiresWiFi,
      retries: _autoRetry ? 5 : 0,
      allowPause: true,
      displayName: oldTask.displayName,
      metaData: oldTask.metaData,
    );
    return _downloader.enqueue(task);
  }

  Future<bool> open(TaskRecord record) async {
    if (record.status != TaskStatus.complete) return false;
    return _downloader.openFile(task: record.task);
  }

  Future<void> deleteHistory(TaskRecord record) async {
    if (!record.status.isFinalState) {
      await cancel(record);
    }
    _telemetry.remove(record.task.taskId);
    await _downloader.database.deleteRecordWithId(record.task.taskId);
    await refreshRecords();
  }

  Future<void> setSimultaneousDownloads(int value) async {
    _simultaneousDownloads = value.clamp(1, 9).toInt();
    await _preferences.setInt(_prefSimultaneous, _simultaneousDownloads);
    await _applyConcurrency();
    notifyListeners();
  }

  Future<void> _applyConcurrency() async {
    await _downloader.configure(
      globalConfig: (
        Config.holdingQueue,
        (_simultaneousDownloads, null, null),
      ),
    );
  }

  Future<void> setAutoRetry(bool value) async {
    _autoRetry = value;
    await _preferences.setBool(_prefAutoRetry, value);
    notifyListeners();
  }

  Future<void> setWifiOnly(bool value) async {
    _wifiOnly = value;
    await _preferences.setBool(_prefWifiOnly, value);
    notifyListeners();
  }

  Future<void> setDownloadDirectory(String value) async {
    _downloadDirectory = _normalizeDirectory(value);
    await _preferences.setString(_prefDirectory, _downloadDirectory);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _preferences.setString(_prefTheme, mode.name);
    notifyListeners();
  }

  Future<void> setMediaExtractionEnabled(bool value) async {
    _mediaExtractionEnabled = value;
    await _preferences.setBool(_prefMediaEnabled, value);
    if (value) {
      _startShareListener();
      await refreshMediaJobs(notify: false);
    } else {
      await _shareSubscription?.cancel();
      _shareSubscription = null;
    }
    _ensureMediaPolling();
    notifyListeners();
  }

  Future<void> setUseAria2(bool value) async {
    _useAria2 = value;
    await _preferences.setBool(_prefUseAria2, value);
    notifyListeners();
  }

  Future<void> setPreferredQuality(int value) async {
    _preferredQuality = value.clamp(0, 4320).toInt();
    await _preferences.setInt(_prefQuality, _preferredQuality);
    notifyListeners();
  }

  Future<String> updateMediaEngine() => _mediaBridge.updateEngine();

  static bool isActiveStatus(TaskStatus status) =>
      directState(status).active;

  static bool isFailureStatus(TaskStatus status) =>
      directState(status).failure;

  static String statusLabel(TaskStatus status) => directState(status).label;

  static String mediaStatusLabel(MediaJobState state) => mediaState(state).label;

  static TransferStateView directState(TaskStatus status) {
    final transferState = switch (status) {
      TaskStatus.enqueued || TaskStatus.waitingToRetry => TransferState.queued,
      TaskStatus.running => TransferState.running,
      TaskStatus.paused => TransferState.paused,
      TaskStatus.complete => TransferState.completed,
      TaskStatus.notFound || TaskStatus.failed => TransferState.failed,
      TaskStatus.canceled => TransferState.canceled,
    };
    return _stateView(transferState, switch (status) {
      TaskStatus.enqueued => 'Queued',
      TaskStatus.running => 'Downloading',
      TaskStatus.complete => 'Completed',
      TaskStatus.notFound => 'Not found',
      TaskStatus.failed => 'Failed',
      TaskStatus.canceled => 'Canceled',
      TaskStatus.waitingToRetry => 'Waiting to retry',
      TaskStatus.paused => 'Paused',
    });
  }

  static TransferStateView mediaState(MediaJobState state) {
    final transferState = switch (state) {
      MediaJobState.queued => TransferState.queued,
      MediaJobState.running => TransferState.running,
      MediaJobState.succeeded => TransferState.completed,
      MediaJobState.failed => TransferState.failed,
      MediaJobState.canceled => TransferState.canceled,
    };
    return _stateView(transferState, switch (state) {
      MediaJobState.queued => 'Queued',
      MediaJobState.running => 'Processing',
      MediaJobState.succeeded => 'Completed',
      MediaJobState.failed => 'Failed',
      MediaJobState.canceled => 'Canceled',
    });
  }

  static TransferStateView _stateView(TransferState state, String label) {
    return TransferStateView(
      state: state,
      label: label,
      active: state == TransferState.queued || state == TransferState.running,
      finalState: state == TransferState.completed ||
          state == TransferState.failed ||
          state == TransferState.canceled,
      failure: state == TransferState.failed || state == TransferState.canceled,
    );
  }

  static String formatBytes(int? bytes) {
    if (bytes == null || bytes < 0) return 'Unknown size';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final decimals = unit == 0 || value >= 100 ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${units[unit]}';
  }

  static String formatSpeed(double? megabytesPerSecond) {
    if (megabytesPerSecond == null || megabytesPerSecond <= 0) return '--';
    if (megabytesPerSecond < 1) {
      return '${(megabytesPerSecond * 1024).toStringAsFixed(0)} KB/s';
    }
    return '${megabytesPerSecond.toStringAsFixed(1)} MB/s';
  }

  static String formatRemaining(Duration? duration) {
    if (duration == null || duration.inSeconds < 0) return '--';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    if (minutes >= 60) {
      final hours = duration.inHours;
      final mins = duration.inMinutes.remainder(60);
      return '${hours}h ${mins}m';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  static String formatMediaDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '--';
    final duration = Duration(seconds: seconds);
    if (duration.inHours > 0) {
      return '${duration.inHours}:${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    }
    return '${duration.inMinutes}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  static MediaJobState _mediaStateFromName(String? value) => switch (value) {
    'running' => MediaJobState.running,
    'succeeded' => MediaJobState.succeeded,
    'failed' => MediaJobState.failed,
    'canceled' => MediaJobState.canceled,
    _ => MediaJobState.queued,
  };

  static String _friendlyMediaError(Object error) {
    final text = error.toString().replaceFirst('PlatformException(', '');
    if (text.length > 260) return '${text.substring(0, 260)}…';
    return text;
  }

  static bool _looksLikeDirectFile(Uri uri) {
    if (uri.pathSegments.isEmpty) return false;
    final last = uri.pathSegments.last.toLowerCase();
    const extensions = {
      'mp4', 'mkv', 'webm', 'mov', 'avi', 'mp3', 'm4a', 'aac', 'flac', 'wav',
      'pdf', 'zip', 'rar', '7z', 'tar', 'gz', 'xz', 'apk', 'aab', 'jpg', 'jpeg',
      'png', 'webp', 'csv', 'txt', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
    };
    final dot = last.lastIndexOf('.');
    return dot >= 0 && extensions.contains(last.substring(dot + 1));
  }

  static String _normalizeDirectory(String value) {
    final parts = value
        .trim()
        .replaceAll('\\', '/')
        .split('/')
        .where((part) => part.isNotEmpty && part != '.' && part != '..')
        .map((part) => part.replaceAll(RegExp(r'[<>:"|?*]'), '_'))
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? 'Downloads' : parts.join('/');
  }

  static String _sanitizeFileName(String value) {
    var name = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    name = name.replaceAll(RegExp(r'^\.+'), '');
    if (name.isEmpty) {
      name = 'download_${DateTime.now().millisecondsSinceEpoch}.bin';
    }
    return name;
  }

  static String? _filenameFromDisposition(String? value) {
    if (value == null || value.isEmpty) return null;
    final match = RegExp(
      r'filename\s*=\s*"?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(value);
    return match?.group(1)?.trim();
  }

  static int? _sizeFromContentRange(String? value) {
    if (value == null || value.isEmpty) return null;
    final match = RegExp(r'/(\d+)$').firstMatch(value.trim());
    return int.tryParse(match?.group(1) ?? '');
  }

  @override
  void dispose() {
    _updatesSubscription?.cancel();
    _databaseSubscription?.cancel();
    _shareSubscription?.cancel();
    _mediaPollTimer?.cancel();
    unawaited(_mediaJobStore.close());
    super.dispose();
  }
}
