import 'dart:convert';

class RemoteFileInfo {
  const RemoteFileInfo({
    required this.url,
    required this.fileName,
    required this.host,
    this.sizeBytes,
    this.mimeType,
  });

  final String url;
  final String fileName;
  final String host;
  final int? sizeBytes;
  final String? mimeType;
}

class TransferTelemetry {
  const TransferTelemetry({
    required this.progress,
    this.expectedFileSize,
    this.networkSpeed,
    this.timeRemaining,
  });

  final double progress;
  final int? expectedFileSize;
  final double? networkSpeed;
  final Duration? timeRemaining;
}

class MediaFormat {
  const MediaFormat({
    required this.id,
    required this.ext,
    this.note,
    this.width,
    this.height,
    this.fps,
    this.videoCodec,
    this.audioCodec,
    this.sizeBytes,
    this.totalBitrate,
    this.audioBitrate,
  });

  factory MediaFormat.fromMap(Map<Object?, Object?> map) {
    int? asInt(Object? value) => value is num ? value.toInt() : null;
    double? asDouble(Object? value) => value is num ? value.toDouble() : null;
    String? asString(Object? value) {
      final text = value?.toString();
      return text == null || text.isEmpty || text == 'null' ? null : text;
    }

    return MediaFormat(
      id: asString(map['id']) ?? '',
      ext: asString(map['ext']) ?? 'unknown',
      note: asString(map['note']),
      width: asInt(map['width']),
      height: asInt(map['height']),
      fps: asInt(map['fps']),
      videoCodec: asString(map['vcodec']),
      audioCodec: asString(map['acodec']),
      sizeBytes: asInt(map['sizeBytes']),
      totalBitrate: asDouble(map['tbr']),
      audioBitrate: asDouble(map['abr']),
    );
  }

  final String id;
  final String ext;
  final String? note;
  final int? width;
  final int? height;
  final int? fps;
  final String? videoCodec;
  final String? audioCodec;
  final int? sizeBytes;
  final double? totalBitrate;
  final double? audioBitrate;

  bool get hasVideo => videoCodec != null && videoCodec != 'none';
  bool get hasAudio => audioCodec != null && audioCodec != 'none';
  bool get isAudioOnly => hasAudio && !hasVideo;
  bool get isVideoOnly => hasVideo && !hasAudio;
  bool get isCombined => hasVideo && hasAudio;

  String get qualityLabel {
    if (isAudioOnly) {
      final bitrate = audioBitrate == null ? '' : ' ${audioBitrate!.round()} kbps';
      return 'Audio $ext$bitrate';
    }
    final resolution = height == null || height == 0 ? note : '${height}p';
    final frameRate = fps == null || fps! <= 30 ? '' : ' ${fps}fps';
    return '${resolution ?? 'Video'}$frameRate • $ext';
  }
}

class MediaEntry {
  const MediaEntry({
    required this.id,
    required this.title,
    this.url,
    this.thumbnail,
    this.durationSeconds,
  });

  factory MediaEntry.fromMap(Map<Object?, Object?> map) => MediaEntry(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? 'Untitled',
        url: map['url']?.toString(),
        thumbnail: map['thumbnail']?.toString(),
        durationSeconds: map['duration'] is num
            ? (map['duration'] as num).round()
            : null,
      );

  final String id;
  final String title;
  final String? url;
  final String? thumbnail;
  final int? durationSeconds;
}

class MediaInfo {
  const MediaInfo({
    required this.url,
    required this.title,
    required this.extractor,
    required this.formats,
    required this.entries,
    this.id,
    this.uploader,
    this.thumbnail,
    this.durationSeconds,
    this.description,
  });

  factory MediaInfo.fromMap(Map<Object?, Object?> map) {
    final rawFormats = map['formats'];
    final rawEntries = map['entries'];
    return MediaInfo(
      url: map['webpageUrl']?.toString() ?? map['url']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled media',
      extractor: map['extractor']?.toString() ?? 'generic',
      id: map['id']?.toString(),
      uploader: map['uploader']?.toString(),
      thumbnail: map['thumbnail']?.toString(),
      durationSeconds: map['duration'] is num
          ? (map['duration'] as num).round()
          : null,
      description: map['description']?.toString(),
      formats: rawFormats is List
          ? rawFormats
              .whereType<Map>()
              .map((e) => MediaFormat.fromMap(e.cast<Object?, Object?>()))
              .where((e) => e.id.isNotEmpty)
              .toList()
          : const [],
      entries: rawEntries is List
          ? rawEntries
              .whereType<Map>()
              .map((e) => MediaEntry.fromMap(e.cast<Object?, Object?>()))
              .toList()
          : const [],
    );
  }

  final String url;
  final String title;
  final String extractor;
  final String? id;
  final String? uploader;
  final String? thumbnail;
  final int? durationSeconds;
  final String? description;
  final List<MediaFormat> formats;
  final List<MediaEntry> entries;

  bool get isPlaylist => entries.isNotEmpty;
}

class LinkInspection {
  const LinkInspection.direct(this.direct) : media = null;
  const LinkInspection.media(this.media) : direct = null;

  final RemoteFileInfo? direct;
  final MediaInfo? media;
  bool get isMedia => media != null;
}

enum MediaJobState { queued, running, succeeded, failed, canceled }

class MediaJob {
  const MediaJob({
    required this.id,
    required this.url,
    required this.title,
    required this.formatLabel,
    required this.formatSelector,
    required this.createdAt,
    required this.state,
    required this.progress,
    required this.playlist,
    required this.wifiOnly,
    required this.useAria2,
    this.audioFormat,
    this.thumbnail,
    this.etaSeconds,
    this.outputPath,
    this.error,
    this.sizeBytes,
  });

  factory MediaJob.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    return MediaJob(
      id: map['id'] as String,
      url: map['url'] as String,
      title: map['title'] as String,
      formatLabel: map['formatLabel'] as String,
      formatSelector: map['formatSelector'] as String,
      audioFormat: map['audioFormat'] as String?,
      thumbnail: map['thumbnail'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      state: MediaJobState.values.firstWhere(
        (e) => e.name == map['state'],
        orElse: () => MediaJobState.queued,
      ),
      progress: (map['progress'] as num?)?.toInt() ?? 0,
      etaSeconds: (map['etaSeconds'] as num?)?.toInt(),
      outputPath: map['outputPath'] as String?,
      error: map['error'] as String?,
      sizeBytes: (map['sizeBytes'] as num?)?.toInt(),
      playlist: map['playlist'] as bool? ?? false,
      wifiOnly: map['wifiOnly'] as bool? ?? false,
      useAria2: map['useAria2'] as bool? ?? true,
    );
  }

  final String id;
  final String url;
  final String title;
  final String formatLabel;
  final String formatSelector;
  final String? audioFormat;
  final String? thumbnail;
  final DateTime createdAt;
  final MediaJobState state;
  final int progress;
  final int? etaSeconds;
  final String? outputPath;
  final String? error;
  final int? sizeBytes;
  final bool playlist;
  final bool wifiOnly;
  final bool useAria2;

  bool get isActive => state == MediaJobState.queued || state == MediaJobState.running;
  bool get isFinal => !isActive;
  bool get isAudioOnly => audioFormat != null;

  MediaJob copyWith({
    String? id,
    MediaJobState? state,
    int? progress,
    int? etaSeconds,
    String? outputPath,
    String? error,
    int? sizeBytes,
  }) {
    return MediaJob(
      id: id ?? this.id,
      url: url,
      title: title,
      formatLabel: formatLabel,
      formatSelector: formatSelector,
      audioFormat: audioFormat,
      thumbnail: thumbnail,
      createdAt: createdAt,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      outputPath: outputPath ?? this.outputPath,
      error: error ?? this.error,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      playlist: playlist,
      wifiOnly: wifiOnly,
      useAria2: useAria2,
    );
  }

  String toJson() => jsonEncode({
        'id': id,
        'url': url,
        'title': title,
        'formatLabel': formatLabel,
        'formatSelector': formatSelector,
        'audioFormat': audioFormat,
        'thumbnail': thumbnail,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'state': state.name,
        'progress': progress,
        'etaSeconds': etaSeconds,
        'outputPath': outputPath,
        'error': error,
        'sizeBytes': sizeBytes,
        'playlist': playlist,
        'wifiOnly': wifiOnly,
        'useAria2': useAria2,
      });
}
