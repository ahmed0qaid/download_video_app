import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'screens/downloads_page.dart';
import 'screens/library_page.dart';
import 'screens/settings_page.dart';
import 'services/download_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final manager = DownloadManager();
  await manager.initialize();
  runApp(DownloadVideoApp(manager: manager));
}

class DownloadVideoApp extends StatefulWidget {
  const DownloadVideoApp({super.key, this.manager});

  final DownloadManager? manager;

  @override
  State<DownloadVideoApp> createState() => _DownloadVideoAppState();
}

class _DownloadVideoAppState extends State<DownloadVideoApp> {
  late final DownloadManager _manager;

  @override
  void initState() {
    super.initState();
    _manager = widget.manager ?? DownloadManager();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _manager,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Download Video App',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _manager.themeMode,
          home: AppShell(manager: _manager),
        );
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.manager});

  final DownloadManager manager;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DownloadsPage(manager: widget.manager),
      LibraryPage(manager: widget.manager),
      SettingsPage(manager: widget.manager),
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
