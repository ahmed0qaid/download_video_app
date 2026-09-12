import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../services/download_manager.dart';
import '../widgets/shared.dart';
import 'inspect_download_page.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key, required this.manager});

  final DownloadManager manager;

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  final _urlController = TextEditingController();
  int _filter = 0;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    setState(() => _urlController.text = data?.text?.trim() ?? '');
  }

  Future<void> _inspect() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showMessage('Paste a direct HTTP or HTTPS file URL first.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InspectDownloadPage(
          manager: widget.manager,
          sourceUrl: url,
        ),
      ),
    );
    if (mounted) {
      await widget.manager.refreshRecords();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.manager,
      builder: (context, _) {
        final records = widget.manager.records.where((record) {
          return switch (_filter) {
            1 => DownloadManager.isActiveStatus(record.status),
            2 => record.status == TaskStatus.complete,
            3 => record.status == TaskStatus.paused,
            4 => DownloadManager.isFailureStatus(record.status),
            _ => true,
          };
        }).toList();
        final activeCount = widget.manager.records
            .where((record) => DownloadManager.isActiveStatus(record.status))
            .length;

        return SafeArea(
          child: Column(
            children: [
              const TransferHeader(subtitle: 'Background download manager'),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: widget.manager.refreshRecords,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Transfers',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                          _StatusBadge(
                            label: '$activeCount active',
                            active: activeCount > 0,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.manager.initializationError == null
                            ? 'Downloads persist across app restarts and can continue in the background.'
                            : 'Downloader initialization failed: ${widget.manager.initializationError}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 22),
                      const SectionLabel('Direct link'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _urlController,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _inspect(),
                        decoration: InputDecoration(
                          hintText: 'https://example.com/video.mp4',
                          prefixIcon: const Icon(Icons.link_rounded, size: 20),
                          suffixIconConstraints: const BoxConstraints(minWidth: 82),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.all(6),
                            child: FilledButton.icon(
                              onPressed: _paste,
                              icon: const Icon(Icons.content_paste_rounded, size: 16),
                              label: const Text('Paste'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: widget.manager.initializationError == null
                              ? _inspect
                              : null,
                          icon: const Icon(Icons.travel_explore_rounded),
                          label: const Text('Inspect link'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final entry in const [
                              (0, 'All'),
                              (1, 'Active'),
                              (2, 'Completed'),
                              (3, 'Paused'),
                              (4, 'Failed'),
                            ]) ...[
                              Pill(
                                label: entry.$2,
                                selected: _filter == entry.$1,
                                onTap: () => setState(() => _filter = entry.$1),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (records.isEmpty)
                        _EmptyState(
                          hasAnyRecords: widget.manager.records.isNotEmpty,
                        )
                      else
                        ...records.map(
                          (record) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _DownloadCard(
                              manager: widget.manager,
                              record: record,
                              onMessage: _showMessage,
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
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({
    required this.manager,
    required this.record,
    required this.onMessage,
  });

  final DownloadManager manager;
  final TaskRecord record;
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppColors.tealDark : AppColors.teal;
    final progress = manager.progressFor(record);
    final telemetry = manager.telemetryFor(record.task.taskId);
    final expectedBytes = manager.expectedSizeFor(record);
    final status = record.status;
    final running = status == TaskStatus.running;
    final active = DownloadManager.isActiveStatus(status);
    final failure = DownloadManager.isFailureStatus(status);

    final icon = status == TaskStatus.complete
        ? Icons.check_circle_outline_rounded
        : status == TaskStatus.paused
        ? Icons.pause_circle_outline_rounded
        : status == TaskStatus.failed || status == TaskStatus.notFound
        ? Icons.error_outline_rounded
        : status == TaskStatus.canceled
        ? Icons.cancel_outlined
        : status == TaskStatus.waitingToRetry
        ? Icons.refresh_rounded
        : status == TaskStatus.enqueued
        ? Icons.schedule_rounded
        : Icons.downloading_rounded;
    final iconColor = failure ? Theme.of(context).colorScheme.error : accent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 21),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.task.filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${DownloadManager.statusLabel(status)} • ${DownloadManager.formatBytes(expectedBytes)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: failure
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                            ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'open':
                        final opened = await manager.open(record);
                        if (!opened) {
                          onMessage('No compatible app could open this file.');
                        }
                        break;
                      case 'delete':
                        await manager.deleteHistory(record);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    if (status == TaskStatus.complete)
                      const PopupMenuItem(value: 'open', child: Text('Open file')),
                    if (status.isFinalState)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Remove from history'),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: active || status == TaskStatus.complete || status == TaskStatus.paused
                    ? progress
                    : 0,
                backgroundColor: dark ? AppColors.nightLine : AppColors.softFill,
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Text(
                  '${(progress * 100).round()}%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: failure ? Theme.of(context).colorScheme.error : accent,
                      ),
                ),
                if (running) ...[
                  const SizedBox(width: 14),
                  _MiniMetric(
                    icon: Icons.speed_rounded,
                    text: DownloadManager.formatSpeed(telemetry?.networkSpeed),
                  ),
                  const SizedBox(width: 12),
                  _MiniMetric(
                    icon: Icons.timer_outlined,
                    text: DownloadManager.formatRemaining(telemetry?.timeRemaining),
                  ),
                ],
                const Spacer(),
                if (running)
                  IconButton(
                    tooltip: 'Pause',
                    onPressed: () async {
                      if (!await manager.pause(record)) {
                        onMessage('This server does not support pausing this download.');
                      }
                    },
                    icon: const Icon(Icons.pause_rounded),
                  )
                else if (status == TaskStatus.paused)
                  IconButton(
                    tooltip: 'Resume',
                    onPressed: () async {
                      if (!await manager.resume(record)) {
                        onMessage('Unable to resume; retry the download instead.');
                      }
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                  )
                else if (failure)
                  TextButton.icon(
                    onPressed: () async {
                      if (!await manager.retry(record)) {
                        onMessage('Retry could not be started.');
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  )
                else if (status == TaskStatus.complete)
                  TextButton.icon(
                    onPressed: () async {
                      if (!await manager.open(record)) {
                        onMessage('No compatible app could open this file.');
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: const Text('Open'),
                  ),
                if (!status.isFinalState)
                  IconButton(
                    tooltip: 'Cancel',
                    onPressed: () => manager.cancel(record),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasAnyRecords});

  final bool hasAnyRecords;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
        child: Column(
          children: [
            Icon(
              hasAnyRecords ? Icons.filter_alt_off_rounded : Icons.download_done_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              hasAnyRecords ? 'No downloads in this filter' : 'No downloads yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              hasAnyRecords
                  ? 'Choose another status filter.'
                  : 'Paste a direct file link above to start your first transfer.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
