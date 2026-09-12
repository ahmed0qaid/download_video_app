import 'package:flutter/material.dart';

import '../services/download_manager.dart';
import '../widgets/shared.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.manager});

  final DownloadManager manager;

  Future<void> _editDirectory(BuildContext context) async {
    final controller = TextEditingController(text: manager.downloadDirectory);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Relative folder',
            helperText: 'Stored inside the app support directory',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) await manager.setDownloadDirectory(value);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: manager,
      builder: (context, _) {
        return SafeArea(
          child: Column(
            children: [
              const TransferHeader(subtitle: 'Settings'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  children: [
                    Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 3),
                    Text(
                      'These preferences are saved on this device and applied to real transfers.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    _SettingsSection(
                      icon: Icons.tune_rounded,
                      title: 'Transfer Engine',
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Simultaneous downloads'),
                          subtitle: const Text('Native holding queue concurrency limit'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Decrease',
                                onPressed: manager.simultaneousDownloads <= 1
                                    ? null
                                    : () => manager.setSimultaneousDownloads(
                                          manager.simultaneousDownloads - 1,
                                        ),
                                icon: const Icon(Icons.remove_rounded),
                              ),
                              Text(
                                '${manager.simultaneousDownloads}',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              IconButton(
                                tooltip: 'Increase',
                                onPressed: manager.simultaneousDownloads >= 9
                                    ? null
                                    : () => manager.setSimultaneousDownloads(
                                          manager.simultaneousDownloads + 1,
                                        ),
                                icon: const Icon(Icons.add_rounded),
                              ),
                            ],
                          ),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Auto-retry failed transfers'),
                          subtitle: const Text('New downloads retry up to 5 times'),
                          value: manager.autoRetry,
                          onChanged: manager.setAutoRetry,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SettingsSection(
                      icon: Icons.wifi_rounded,
                      title: 'Network',
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Wi-Fi only'),
                          subtitle: const Text(
                            'Use Wi-Fi only by default for new transfers',
                          ),
                          value: manager.wifiOnly,
                          onChanged: manager.setWifiOnly,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SettingsSection(
                      icon: Icons.folder_open_rounded,
                      title: 'Storage',
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Default download directory'),
                          subtitle: Text(
                            'App support / ${manager.downloadDirectory}',
                          ),
                          trailing: const Icon(Icons.edit_outlined),
                          onTap: () => _editDirectory(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SettingsSection(
                      icon: Icons.palette_outlined,
                      title: 'Appearance',
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Theme'),
                          subtitle: const Text('App color mode'),
                          trailing: DropdownButton<ThemeMode>(
                            value: manager.themeMode,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(
                                value: ThemeMode.system,
                                child: Text('System'),
                              ),
                              DropdownMenuItem(
                                value: ThemeMode.light,
                                child: Text('Light'),
                              ),
                              DropdownMenuItem(
                                value: ThemeMode.dark,
                                child: Text('Dark'),
                              ),
                            ],
                            onChanged: (mode) {
                              if (mode != null) manager.setThemeMode(mode);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        'Download Video App • Background engine enabled',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 6),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 5),
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index != children.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}
