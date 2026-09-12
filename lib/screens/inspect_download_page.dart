import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../widgets/shared.dart';

class InspectDownloadPage extends StatefulWidget {
  const InspectDownloadPage({super.key, this.sourceUrl = ''});

  final String sourceUrl;

  @override
  State<InspectDownloadPage> createState() => _InspectDownloadPageState();
}

class _InspectDownloadPageState extends State<InspectDownloadPage> {
  bool _turbo = true;
  bool _wifiOnly = true;
  bool _verify = true;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppColors.tealDark : AppColors.teal;
    final fileName = widget.sourceUrl.isEmpty
        ? 'linux-6.9.12-source.tar.xz'
        : Uri.tryParse(widget.sourceUrl)?.pathSegments.lastOrNull ?? 'download.bin';

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        titleSpacing: 0,
        title: const Row(
          children: [
            _MiniLogo(),
            SizedBox(width: 9),
            Text('Inspect Add'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: accent,
              child: const Icon(Icons.person_rounded, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.travel_explore_rounded, color: accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Inspect Download', style: Theme.of(context).textTheme.titleMedium),
                              Text('Pre-flight link handshake ready', style: Theme.of(context).textTheme.labelMedium),
                            ],
                          ),
                        ),
                        const Icon(Icons.close_rounded, size: 18),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: dark ? AppColors.nightCanvas : AppColors.canvas,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: dark ? AppColors.nightLine : AppColors.line),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.folder_zip_rounded, color: accent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('archive.kernel.org', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: accent)),
                                const SizedBox(height: 2),
                                Text('HTTPS Verified', style: Theme.of(context).textTheme.labelMedium),
                              ],
                            ),
                          ),
                          Icon(Icons.verified_user_outlined, size: 18, color: accent),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(fileName, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Expanded(child: _InfoBox(label: 'Payload Size', value: '142.6 MB')),
                        SizedBox(width: 8),
                        Expanded(child: _InfoBox(label: 'MIME Type', value: 'application/x-xz')),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SectionLabel(
                      'Storage Destination',
                      trailing: Text('18.4 GB Free', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: accent)),
                    ),
                    const SizedBox(height: 8),
                    _SettingTile(
                      icon: Icons.folder_open_rounded,
                      title: 'Internal Storage',
                      subtitle: '/Downloads/Kernel/',
                      trailing: OutlinedButton(onPressed: () {}, child: const Text('Change')),
                    ),
                    const SizedBox(height: 16),
                    const SectionLabel('Concurrency Allocation'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ChoiceCard(
                            selected: !_turbo,
                            title: 'Standard',
                            subtitle: '4 Threads',
                            onTap: () => setState(() => _turbo = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ChoiceCard(
                            selected: _turbo,
                            title: '⚡ Turbo',
                            subtitle: '16 Threads',
                            onTap: () => setState(() => _turbo = true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ToggleCard(
                      icon: Icons.wifi_rounded,
                      title: 'Wi-Fi Only',
                      subtitle: 'Conserve metered cellular data',
                      value: _wifiOnly,
                      onChanged: (v) => setState(() => _wifiOnly = v),
                    ),
                    const SizedBox(height: 10),
                    ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: const Icon(Icons.fingerprint_rounded),
                      title: const Text('Checksum & Verification'),
                      childrenPadding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Auto-verify integrity upon completion'),
                          subtitle: const Text('Expected SHA-256 Digest'),
                          value: _verify,
                          onChanged: (v) => setState(() => _verify = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Download added to queue')),
                          );
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Start Download'),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel & Discard'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.network_ping_rounded, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Global Node Routing', style: Theme.of(context).textTheme.titleMedium),
                          Text('Mirror selected: sjc-us.kernel.org', style: Theme.of(context).textTheme.labelMedium),
                        ],
                      ),
                    ),
                    Text('24 ms', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: accent)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _LastOrNull<T> on List<T> {
  T? get lastOrNull => isEmpty ? null : last;
}

class _MiniLogo extends StatelessWidget {
  const _MiniLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Icon(Icons.download_rounded, size: 20, color: Colors.white),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: dark ? AppColors.nightCanvas : AppColors.canvas,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: dark ? AppColors.nightCanvas : AppColors.canvas,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                Text(subtitle, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? accent : Theme.of(context).dividerColor),
          color: selected ? accent.withValues(alpha: .08) : Colors.transparent,
        ),
        child: Column(
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: selected ? accent : null)),
            const SizedBox(height: 2),
            Text(subtitle, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
      decoration: BoxDecoration(
        color: dark ? AppColors.nightCanvas : AppColors.canvas,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                Text(subtitle, style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
