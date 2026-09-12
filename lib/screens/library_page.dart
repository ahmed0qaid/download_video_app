import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';

import '../services/download_manager.dart';
import '../widgets/shared.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.manager});

  final DownloadManager manager;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _search = TextEditingController();
  int _category = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.manager,
      builder: (context, _) {
        final query = _search.text.trim().toLowerCase();
        final completed = widget.manager.records
            .where((record) => record.status == TaskStatus.complete)
            .where((record) => record.task.filename.toLowerCase().contains(query))
            .where((record) => _matchesCategory(record.task.filename, _category))
            .toList();

        return SafeArea(
          child: Column(
            children: [
              const TransferHeader(subtitle: 'Downloaded files'),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: widget.manager.refreshRecords,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    children: [
                      Text('Library', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 3),
                      Text(
                        '${widget.manager.records.where((r) => r.status == TaskStatus.complete).length} completed downloads',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search downloaded files…',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _search.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final entry in const [
                              (0, 'All'),
                              (1, 'Documents'),
                              (2, 'Media'),
                              (3, 'Archives'),
                              (4, 'Installers'),
                            ]) ...[
                              Pill(
                                label: entry.$2,
                                selected: _category == entry.$1,
                                onTap: () => setState(() => _category = entry.$1),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (completed.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 34,
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.folder_open_rounded,
                                  size: 42,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No matching downloaded files',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Completed transfers will appear here automatically.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...completed.map(
                          (record) => Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: _LibraryRow(
                              manager: widget.manager,
                              record: record,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static bool _matchesCategory(String filename, int category) {
    if (category == 0) return true;
    final extension = filename.contains('.')
        ? filename.split('.').last.toLowerCase()
        : '';
    return switch (category) {
      1 => {'pdf', 'doc', 'docx', 'txt', 'csv', 'xls', 'xlsx', 'ppt', 'pptx'}
          .contains(extension),
      2 => {'mp4', 'mkv', 'mov', 'avi', 'mp3', 'wav', 'flac', 'm4a', 'jpg', 'jpeg', 'png', 'webp'}
          .contains(extension),
      3 => {'zip', 'rar', '7z', 'tar', 'gz', 'xz', 'bz2'}.contains(extension),
      4 => {'apk', 'aab', 'exe', 'msi', 'dmg', 'deb', 'rpm'}.contains(extension),
      _ => true,
    };
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({required this.manager, required this.record});

  final DownloadManager manager;
  final TaskRecord record;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final filename = record.task.filename;
    final extension = filename.contains('.')
        ? filename.split('.').last.toUpperCase()
        : 'FILE';

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_iconFor(filename), color: accent, size: 21),
        ),
        title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${DownloadManager.formatBytes(manager.expectedSizeFor(record))} • $extension',
        ),
        onTap: () async {
          final opened = await manager.open(record);
          if (!context.mounted || opened) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No compatible app could open this file.')),
          );
        },
        trailing: IconButton(
          tooltip: 'Open',
          onPressed: () async {
            final opened = await manager.open(record);
            if (!context.mounted || opened) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No compatible app could open this file.')),
            );
          },
          icon: const Icon(Icons.open_in_new_rounded),
        ),
      ),
    );
  }

  static IconData _iconFor(String filename) {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
    if ({'mp4', 'mkv', 'mov', 'avi'}.contains(ext)) return Icons.movie_outlined;
    if ({'mp3', 'wav', 'flac', 'm4a'}.contains(ext)) return Icons.audio_file_outlined;
    if ({'jpg', 'jpeg', 'png', 'webp'}.contains(ext)) return Icons.image_outlined;
    if ({'zip', 'rar', '7z', 'tar', 'gz', 'xz'}.contains(ext)) return Icons.folder_zip_outlined;
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if ({'apk', 'aab'}.contains(ext)) return Icons.android_rounded;
    return Icons.insert_drive_file_outlined;
  }
}
