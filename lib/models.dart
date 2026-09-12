enum DownloadStatus { active, paused, completed, failed }

class DownloadItem {
  const DownloadItem({
    required this.name,
    required this.detail,
    required this.size,
    required this.status,
    this.progress = 0,
  });

  final String name;
  final String detail;
  final String size;
  final DownloadStatus status;
  final double progress;
}

class LibraryItem {
  const LibraryItem({
    required this.name,
    required this.size,
    required this.meta,
    required this.type,
  });

  final String name;
  final String size;
  final String meta;
  final String type;
}
