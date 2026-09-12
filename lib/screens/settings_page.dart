import 'package:flutter/material.dart';

import '../widgets/shared.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _simultaneous = 3;
  bool _autoRetry = true;
  bool _wifiOnly = false;
  bool _wakeLock = true;
  bool _autoCategorize = true;
  bool _arabic = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: Column(
        children: [
          const TransferHeader(subtitle: 'Settings'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                const SectionLabel('Preferences & Config'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: Text('Settings', style: Theme.of(context).textTheme.headlineMedium)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text('CONFIG ACTIVE', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: accent, fontSize: 9)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsSection(
                  icon: Icons.tune_rounded,
                  title: 'Transfer Engine',
                  caption: 'Core concurrency',
                  children: [
                    _StepperTile(
                      title: 'Simultaneous downloads',
                      subtitle: 'Concurrent payload throughput limit',
                      value: _simultaneous,
                      onMinus: () => setState(() => _simultaneous = (_simultaneous - 1).clamp(1, 9).toInt()),
                      onPlus: () => setState(() => _simultaneous = (_simultaneous + 1).clamp(1, 9).toInt()),
                    ),
                    const _NavTile(title: 'Max download speed', subtitle: 'Tap to configure bandwidth ceiling', value: 'Unlimited'),
                    const _NavTile(title: 'Default connection threads', subtitle: 'Multi-segmented chunk allocation', value: '8 connections'),
                    _SwitchTile(title: 'Auto-retry failed transfers', subtitle: 'Exponential backoff up to 5 cycles', value: _autoRetry, onChanged: (v) => setState(() => _autoRetry = v)),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  icon: Icons.wifi_tethering_rounded,
                  title: 'Network & Battery',
                  caption: 'Data consumption',
                  children: [
                    _SwitchTile(title: 'Download on Wi-Fi only', subtitle: 'Pause automatically on cellular radio', value: _wifiOnly, onChanged: (v) => setState(() => _wifiOnly = v)),
                    _SwitchTile(title: 'Prevent sleep while downloading', subtitle: 'Acquire partial wake lock during activity', value: _wakeLock, onChanged: (v) => setState(() => _wakeLock = v)),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  icon: Icons.folder_open_rounded,
                  title: 'Storage & Paths',
                  caption: 'File system',
                  children: [
                    const _NavTile(title: 'Default download directory', subtitle: '/storage/emulated/0/Download', value: ''),
                    _SwitchTile(title: 'Auto-categorize by file type', subtitle: 'Route into Video, Audio, Archives, APKs', value: _autoCategorize, onChanged: (v) => setState(() => _autoCategorize = v)),
                    const _NavTile(title: 'Storage cleaner', subtitle: 'Purge orphan partial chunks & temp headers', value: 'Clear (142 MB)', destructive: true),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  icon: Icons.language_rounded,
                  title: 'Interface & Localization',
                  caption: 'Display params',
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Theme'),
                      subtitle: const Text('Interface rendering mode'),
                      trailing: DropdownButton<ThemeMode>(
                        value: widget.themeMode,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: ThemeMode.system, child: Text('System default')),
                          DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                          DropdownMenuItem(value: ThemeMode.dark, child: Text('Night Mode')),
                        ],
                        onChanged: (mode) {
                          if (mode != null) widget.onThemeChanged(mode);
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Language / Direction'),
                      subtitle: const Text('Text alignment and layout geometry'),
                      trailing: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('EN')),
                          ButtonSegment(value: true, label: Text('عربي')),
                        ],
                        selected: {_arabic},
                        onSelectionChanged: (values) => setState(() => _arabic = values.first),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.terminal_rounded, color: accent, size: 18),
                      const SizedBox(height: 6),
                      Text('Engineered Utility v2.4.0 (Build 8421)', style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(height: 2),
                      Text('Hardware acceleration: Active • SQLite engine: WAL mode', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 10)),
                    ],
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.caption,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String caption;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 5),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                Text(caption, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 9)),
              ],
            ),
            const SizedBox(height: 6),
            ..._withDividers(children),
          ],
        ),
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> source) {
    final result = <Widget>[];
    for (var i = 0; i < source.length; i++) {
      result.add(source[i]);
      if (i != source.length - 1) result.add(const Divider(height: 1));
    }
    return result;
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({required this.title, required this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.title, required this.subtitle, required this.value, this.destructive = false});

  final String title;
  final String subtitle;
  final String value;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.isNotEmpty)
            Text(
              value,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: destructive ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                  ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 18),
        ],
      ),
    );
  }
}

class _StepperTile extends StatelessWidget {
  const _StepperTile({required this.title, required this.subtitle, required this.value, required this.onMinus, required this.onPlus});

  final String title;
  final String subtitle;
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_rounded, size: 18)),
          Text('$value active', style: Theme.of(context).textTheme.labelLarge),
          IconButton(onPressed: onPlus, icon: const Icon(Icons.add_rounded, size: 18)),
        ],
      ),
    );
  }
}
