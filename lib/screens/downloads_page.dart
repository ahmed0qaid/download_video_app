import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models.dart';
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
  void initState() {
    super.initState();
    widget.manager.addListener(_managerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeSharedUrl());
  }

  @override
  void dispose() {
    widget.manager.removeListener(_managerChanged);
    _urlController.dispose();
    super.dispose();
  }

  void _managerChanged() => _consumeSharedUrl();

  void _consumeSharedUrl() {
    if (!mounted || widget.manager.pendingSharedUrl == null) return;
    final shared = widget.manager.consumePendingSharedUrl();
    if (shared == null || shared.isEmpty) return;
    setState(() {
      _urlController.text = shared;
      _urlController.selection = TextSelection.collapsed(
        offset: _urlController.text.length,
      );
    });
    _showMessage('Shared link received. Review it, then tap Inspect link.');
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    setState(() => _urlController.text = data?.text?.trim() ?? '');
  }

  Future<void> _inspect() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showMessage('Paste a video page or direct file URL first.');
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
    if (mounted) await widget.manager.refreshAll();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.manager,
      builder: (context, _) {
        final directRecords = widget.manager.records.where(_matchesDirectFilter).toList();
        final mediaRecords = widget.manager.mediaJobs.where(_matchesMediaFilter).toList();
        final activeCount = widget.manager.records
                .where((record) => DownloadManager.isActiveStatus(record.status))
                .length +
            widget.manager.mediaJobs.where((job) => job.isActive).length;
        final hasAnyRecords =
            widget.manager.records.isNotEmpty || widget.manager.mediaJobs.isNotEmpty;

        return SafeArea(
          child: Column(
            children: [
              const TransferHeader(subtitle: 'Direct + media download engine'),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: widget.manager.refreshAll,
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
                            ? 'Paste a public media page, playlist, or direct HTTP/HTTPS file URL.'
                            : 'Downloader initialization warning: ${widget.manager.initializationError}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 22),
                      const SectionLabel('Link'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _urlController,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _inspect(),
                        decoration: InputDecoration(
                          hintText: 'https://example.com/video-or-file',
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
                      if (directRecords.isEmpty && mediaRecords.isEmpty)
                        _EmptyState(hasAnyRecords: hasAnyRecords)
                      else ...[
                        if (mediaRecords.isNotEmpty) ...[
                          const SectionLabel('Media downloads'),
                          const SizedBox(height: 8),
                          ...mediaRecords.map(
                            (job) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _MediaDownloadCard(
                                manager: widget.manager,
                                job: job,
                                onMessage: _showMessage,
                              ),
                            ),
                          ),
                        ],
                        if (directRecords.isNotEmpty) ...[
                          if (mediaRecords.isNotEmpty) const SizedBox(height: 8),
                          const SectionLabel('Direct transfers'),
                          const SizedBox(height: 8),
                          ...directRecords.map(
                            (record) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _DirectDownloadCard(
                                manager: widget.manager,
                                record: record,
                                onMessage: _showMessage,
                              ),
                            ),
                          ),
                        ],
                      ],
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

  bool _matchesDirectFilter(TaskRecord record) => switch (_filter) {
        1 => DownloadManager.isActiveStatus(record.status),
        2 => record.status == TaskStatus.complete,
        3 => record.status == TaskStatus.paused,
        4 => DownloadManager.isFailureStatus(record.status),
        _ => true,
      };

  bool _matchesMediaFilter(MediaJob job) => switch (_filter) {
        1 => job.isActive,
        2 => job.state == MediaJobState.succeeded,
        3 => false,
        4 => job.state == MediaJobState.failed || job.state == MediaJobState.canceled,
        _ => true,
      };
}

class _MediaDownloadCard extends StatelessWidget {
  const _MediaDownloadCard({
    required this.manager,
    required this.job,
    required this.onMessage,
  });

  final DownloadManager manager;
  final MediaJob job;
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final failure = job.state == MediaJobState.failed || job.state == MediaJobState.canceled;
    final progress = job.state == MediaJobState.succeeded
        ? 1.0
        : (job.progress / 100).clamp(0.0, 1.0);
    final color = failure ? Theme.of(context).colorScheme.error : accent;
    final icon = switch (job.state) {
      MediaJobState.queued => Icons.schedule_rounded,
      MediaJobState.running => Icons.video_settings_rounded,
      MediaJobState.succeeded => Icons.check_circle_outline_rounded,
      MediaJobState.failed => Icons.error_outline_rounded,
      MediaJobState.canceled => Icons.cancel_outlined,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${DownloadManager.mediaStatusLabel(job.state)} • ${job.formatLabel}${job.playlist ? ' • Playlist' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: failure ? Theme.of(context).colorScheme.error : null,
                            ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'open':
                        if (!await manager.openMediaJob(job)) {
                          onMessage('The output could not be opened.');
                        }
                      case 'share':
                        if (!await manager.shareMediaJob(job)) {
                          onMessage('The output could not be shared.');
                        }
                      case 'delete':
                        await manager.deleteMediaHistory(job);
                    }
                  },
                  itemBuilder: (_) => [
                    if (job.state == MediaJobState.succeeded && !job.playlist) ...[
                      const PopupMenuItem(value: 'open', child: Text('Open file')),
                      const PopupMenuItem(value: 'share', child: Text('Share file')),
                    ],
                    if (job.isFinal)
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
                value: progress,
                backgroundColor: Theme.of(context).dividerColor,
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Text(
                  '${(progress * 100).round()}%',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
                ),
                if (job.state == MediaJobState.running && job.etaSeconds != null) ...[
                  const SizedBox(width: 14),
                  _MiniMetric(
                    icon: Icons.timer_outlined,
                    text: DownloadManager.formatRemaining(
                      Duration(seconds: job.etaSeconds!),
                    ),
                  ),
                ],
                if (job.sizeBytes != null && job.sizeBytes! > 0) ...[
                  const SizedBox(width: 14),
                  _MiniMetric(
                    icon: Icons.storage_rounded,
                    text: DownloadManager.formatBytes(job.sizeBytes),
                  ),
                ],
                const Spacer(),
                if (job.isActive)
                  IconButton(
                    tooltip: 'Cancel',
                    onPressed: () => manager.cancelMediaJob(job),
                    icon: const Icon(Icons.close_rounded),
                  )
                else if (failure)
                  TextButton.icon(
                    onPressed: () => manager.retryMediaJob(job),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  )
                else if (job.state == MediaJobState.succeeded && !job.playlist)
                  TextButton.icon(
                    onPressed: () async {
                      if (!await manager.openMediaJob(job)) {
                        onMessage('The output could not be opened.');
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: const Text('Open'),
                  ),
              ],
            ),
            if (job.error?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  job.error!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DirectDownloadCard extends StatelessWidget {
  const _DirectDownloadCard({
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
                    if (value == 'open') {
                      final opened = await manager.open(record);
                      if (!opened) onMessage('No compatible app could open this file.');
                    } else if (value == 'delete') {
                      await manager.deleteHistory(record);
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
                      if (!await manager.retry(record)) onMessage('Retry could not be started.');
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
                  : 'Paste a public media page, playlist, or direct file link above.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
