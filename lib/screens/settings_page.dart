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
        title: const Text('Direct-download folder'),
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

  Future<void> _updateExtractor(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Checking for a yt-dlp extractor update…')),
    );
    try {
      final result = await manager.updateMediaEngine();
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(result)));
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Extractor update failed: $error')),
      );
    }
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
                      'Direct transfers and public media extraction use separate engines so one cannot break the other.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    _SettingsSection(
                      icon: Icons.smart_display_outlined,
                      title: 'Media Engine',
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Video/audio site extraction'),
                          subtitle: const Text(
                            'Use yt-dlp for public media pages and playlists',
                          ),
                          value: manager.mediaExtractionEnabled,
                          onChanged: manager.setMediaExtractionEnabled,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Preferred video quality'),
                          subtitle: const Text('Used as the recommended format during inspection'),
                          trailing: DropdownButton<int>(
                            value: manager.preferredQuality,
                            underline: const SizedBox.shrink(),
                            items: const [
                              DropdownMenuItem(value: 0, child: Text('Best')),
                              DropdownMenuItem(value: 2160, child: Text('2160p')),
                              DropdownMenuItem(value: 1440, child: Text('1440p')),
                              DropdownMenuItem(value: 1080, child: Text('1080p')),
                              DropdownMenuItem(value: 720, child: Text('720p')),
                              DropdownMenuItem(value: 480, child: Text('480p')),
                              DropdownMenuItem(value: 360, child: Text('360p')),
                            ],
                            onChanged: manager.mediaExtractionEnabled
                                ? (value) {
                                    if (value != null) manager.setPreferredQuality(value);
                                  }
                                : null,
                          ),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Aria2 acceleration'),
                          subtitle: const Text(
                            'Let yt-dlp use Aria2 when the source supports it',
                          ),
                          value: manager.useAria2,
                          onChanged: manager.mediaExtractionEnabled
                              ? manager.setUseAria2
                              : null,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.system_update_alt_rounded),
                          title: const Text('Update yt-dlp extractor'),
                          subtitle: const Text(
                            'Refresh site extractors without changing the Flutter app',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          enabled: manager.mediaExtractionEnabled,
                          onTap: manager.mediaExtractionEnabled
                              ? () => _updateExtractor(context)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SettingsSection(
                      icon: Icons.tune_rounded,
                      title: 'Direct Transfer Engine',
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
                          subtitle: const Text('New direct downloads retry up to 5 times'),
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
                            'Use unmetered Wi-Fi by default for new direct and media jobs',
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
                          title: const Text('Direct-download directory'),
                          subtitle: Text('App support / ${manager.downloadDirectory}'),
                          trailing: const Icon(Icons.edit_outlined),
                          onTap: () => _editDirectory(context),
                        ),
                        const ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Video/audio directory'),
                          subtitle: Text('Public Downloads / Download Video App'),
                          leading: Icon(Icons.video_file_outlined),
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
                    const SizedBox(height: 12),
                    _SettingsSection(
                      icon: Icons.shield_outlined,
                      title: 'Responsible use',
                      children: const [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Public and permitted media only'),
                          subtitle: Text(
                            'No DRM bypass, paywall bypass, premium unlocking, or private-account cookie extraction is implemented.',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        'Download Video App • Direct + yt-dlp media engines',
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
