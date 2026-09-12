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
