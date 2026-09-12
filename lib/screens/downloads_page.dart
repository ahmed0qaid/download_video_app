import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../models.dart';
import '../widgets/shared.dart';
import 'inspect_download_page.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  final _urlController = TextEditingController();
  int _filter = 0;

  final _items = const [
    DownloadItem(
      name: 'archlinux-2026.03.01-x86_64.iso',
      detail: '2.1 GB Total • Mirror 04 (FRA)',
      size: '1.34 / 2.1 GB',
      status: DownloadStatus.active,
      progress: .64,
    ),
    DownloadItem(
      name: 'ubuntu-server-arm64.iso',
      detail: '1.4 GB • Paused at 42%',
      size: '1.4 GB',
      status: DownloadStatus.paused,
      progress: .42,
    ),
    DownloadItem(
      name: 'lecture-09-servo-gate.pdf',
      detail: '18.4 MB • Completed',
      size: '18.4 MB',
      status: DownloadStatus.completed,
      progress: 1,
    ),
    DownloadItem(
      name: 'firmware_v2.4.bin',
      detail: '420 MB • Failed (Network timeout)',
      size: '420 MB',
      status: DownloadStatus.failed,
      progress: .18,
    ),
  ];

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    setState(() => _urlController.text = data?.text ?? '');
  }

  Future<void> _inspect() async {
    final url = _urlController.text.trim();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InspectDownloadPage(sourceUrl: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppColors.tealDark : AppColors.teal;
    final visible = _items.where((item) {
      return switch (_filter) {
        1 => item.status == DownloadStatus.active,
        2 => item.status == DownloadStatus.completed,
        3 => item.status == DownloadStatus.paused,
        _ => true,
      };
    }).toList();

    return SafeArea(
      child: Column(
        children: [
          const TransferHeader(subtitle: 'Home'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Transfers', style: Theme.of(context).textTheme.headlineMedium),
                    ),
                    Icon(Icons.pie_chart_outline_rounded, size: 17, color: accent),
                    const SizedBox(width: 6),
                    Text('48.2 GB free of 128 GB', style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Continuous transfer daemon running • 1 active pipeline',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 22),
                SectionLabel(
                  'Direct Stream Ingest',
                  trailing: Text(
                    'HTTP/FTP/MAGNET',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: accent),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  onSubmitted: (_) => _inspect(),
                  decoration: InputDecoration(
                    hintText: 'Paste download link…',
                    prefixIcon: const Icon(Icons.link_rounded, size: 20),
                    suffixIconConstraints: const BoxConstraints(minWidth: 84),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.all(6),
                      child: FilledButton.icon(
                        onPressed: _paste,
                        icon: const Icon(Icons.content_paste_rounded, size: 16),
                        label: const Text('Paste'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _inspect,
                    icon: const Icon(Icons.travel_explore_rounded, size: 18),
                    label: const Text('Inspect download'),
                  ),
                ),
                const SizedBox(height: 10),
                _ActiveCard(item: _items.first),
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in const [
                        (0, 'All (4)'),
                        (1, 'Active (2)'),
                        (2, 'Completed (1)'),
                        (3, 'Paused (1)'),
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
                const SizedBox(height: 12),
                ...visible.skip(1).map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DownloadRow(item: item),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveCard extends StatelessWidget {
  const _ActiveCard({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppColors.tealDark : AppColors.teal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          children: [
            Row(
              children: [
                _FileIcon(icon: Icons.album_rounded, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(item.detail, style: Theme.of(context).textTheme.labelMedium),
                    ],
                  ),
                ),
                IconButton(onPressed: () {}, icon: const Icon(Icons.pause_rounded)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.close_rounded)),
              ],
            ),
            const SizedBox(height: 11),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 5,
                value: item.progress,
                backgroundColor: dark ? AppColors.nightLine : AppColors.softFill,
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('64%', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: accent)),
                const Spacer(),
                _Metric(icon: Icons.speed_rounded, value: '4.8 MB/s'),
                const SizedBox(width: 16),
                const _Metric(icon: Icons.timer_outlined, value: '2m 14s left'),
                const SizedBox(width: 16),
                _Metric(icon: Icons.data_usage_rounded, value: item.size),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppColors.tealDark : AppColors.teal;
    final (icon, color, action, actionIcon) = switch (item.status) {
      DownloadStatus.paused => (Icons.pause_circle_outline_rounded, AppColors.steel, 'Resume', Icons.play_arrow_rounded),
      DownloadStatus.completed => (Icons.check_circle_outline_rounded, accent, 'Open', Icons.arrow_forward_rounded),
      DownloadStatus.failed => (Icons.warning_amber_rounded, Theme.of(context).colorScheme.error, 'Retry', Icons.refresh_rounded),
      DownloadStatus.active => (Icons.downloading_rounded, accent, 'Pause', Icons.pause_rounded),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _FileIcon(icon: icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.detail,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: item.status == DownloadStatus.failed
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: Icon(actionIcon, size: 16),
              label: Text(action),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileIcon extends StatelessWidget {
  const _FileIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 21, color: color),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 4),
        Text(value, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
