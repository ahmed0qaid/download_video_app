import 'dart:async';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class DownloadManager extends ChangeNotifier {
  static const _prefTheme = 'theme_mode';
  static const _prefSimultaneous = 'simultaneous_downloads';
  static const _prefAutoRetry = 'auto_retry';
  static const _prefWifiOnly = 'wifi_only';
  static const _prefDirectory = 'download_directory';

  FileDownloader? _downloaderInstance;
  SharedPreferencesAsync? _preferencesInstance;
  StreamSubscription<TaskUpdate>? _updatesSubscription;
  StreamSubscription<TaskRecord>? _databaseSubscription;

  final Map<String, TransferTelemetry> _telemetry = {};
  List<TaskRecord> _records = const [];

  bool _initialized = false;
  String? _initializationError;
  int _simultaneousDownloads = 3;
  bool _autoRetry = true;
  bool _wifiOnly = false;
  String _downloadDirectory = 'Downloads';
  ThemeMode _themeMode = ThemeMode.system;

  FileDownloader get _downloader =>
      _downloaderInstance ??= FileDownloader();
  SharedPreferencesAsync get _preferences =>
      _preferencesInstance ??= SharedPreferencesAsync();

  bool get initialized => _initialized;
  String? get initializationError => _initializationError;
  List<TaskRecord> get records => List.unmodifiable(_records);
  int get simultaneousDownloads => _simultaneousDownloads;
  bool get autoRetry => _autoRetry;
  bool get wifiOnly => _wifiOnly;
  String get downloadDirectory => _downloadDirectory;
  ThemeMode get themeMode => _themeMode;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _loadPreferences();

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
    } catch (error) {
      _initializationError = error.toString();
    } finally {
      _initialized = true;
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

    final storedTheme = await _preferences.getString(_prefTheme);
    _themeMode = switch (storedTheme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
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
        ..headers['User-Agent'] = 'DownloadVideoApp/1.1';
      final response = await client
          .send(request)
          .timeout(const Duration(seconds: 15));

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
      final fileName = _sanitizeFileName(
        headerName?.isNotEmpty == true
            ? headerName!
            : (pathName?.isNotEmpty == true
                  ? pathName!
                  : 'download_${DateTime.now().millisecondsSinceEpoch}.bin'),
      );

      return RemoteFileInfo(
        url: uri.toString(),
        fileName: fileName,
        host: uri.host,
        sizeBytes: response.contentLength != null && response.contentLength! > 0
            ? response.contentLength
            : null,
        mimeType: response.headers['content-type']?.split(';').first.trim(),
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

  static bool isActiveStatus(TaskStatus status) =>
      status == TaskStatus.enqueued ||
      status == TaskStatus.running ||
      status == TaskStatus.waitingToRetry;

  static bool isFailureStatus(TaskStatus status) =>
      status == TaskStatus.failed ||
      status == TaskStatus.notFound ||
      status == TaskStatus.canceled;

  static String statusLabel(TaskStatus status) => switch (status) {
    TaskStatus.enqueued => 'Queued',
    TaskStatus.running => 'Downloading',
    TaskStatus.complete => 'Completed',
    TaskStatus.notFound => 'Not found',
    TaskStatus.failed => 'Failed',
    TaskStatus.canceled => 'Canceled',
    TaskStatus.waitingToRetry => 'Waiting to retry',
    TaskStatus.paused => 'Paused',
  };

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

  @override
  void dispose() {
    _updatesSubscription?.cancel();
    _databaseSubscription?.cancel();
    super.dispose();
  }
}
