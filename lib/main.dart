import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'screens/downloads_page.dart';
import 'screens/library_page.dart';
import 'screens/settings_page.dart';

void main() {
  runApp(const DownloadVideoApp());
}

class DownloadVideoApp extends StatefulWidget {
  const DownloadVideoApp({super.key});

  @override
  State<DownloadVideoApp> createState() => _DownloadVideoAppState();
}

class _DownloadVideoAppState extends State<DownloadVideoApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Transfers',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: AppShell(
        themeMode: _themeMode,
        onThemeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DownloadsPage(),
      const LibraryPage(),
      SettingsPage(themeMode: widget.themeMode, onThemeChanged: widget.onThemeChanged),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download_rounded),
            label: 'Downloads',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded),
            label: 'Files',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
