import 'package:flutter/material.dart';

import 'models/app_config.dart';
import 'screens/home_screen.dart';
import 'screens/rag_sources_screen.dart';
import 'screens/settings_screen.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RagMcpApp());
}

class RagMcpApp extends StatefulWidget {
  const RagMcpApp({super.key});

  @override
  State<RagMcpApp> createState() => _RagMcpAppState();
}

class _RagMcpAppState extends State<RagMcpApp> {
  final StorageService _storageService = StorageService();
  bool _loading = true;
  int _selectedIndex = 0;
  AppConfig _config = const AppConfig();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await _storageService.loadConfig();
    if (!mounted) {
      return;
    }
    setState(() {
      _config = config;
      _loading = false;
    });
  }

  Future<void> _saveConfig(AppConfig config) async {
    await _storageService.saveConfig(config);
    if (!mounted) {
      return;
    }
    setState(() {
      _config = config;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "ragmcp",
      theme: AppTheme.build(),
      home: _loading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : Scaffold(
              body: SafeArea(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    HomeScreen(
                      config: _config,
                      onOpenSources: () => setState(() => _selectedIndex = 1),
                      onOpenSettings: () => setState(() => _selectedIndex = 2),
                    ),
                    RagSourcesScreen(config: _config),
                    SettingsScreen(
                      initialConfig: _config,
                      onSaved: _saveConfig,
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) {
                  setState(() => _selectedIndex = index);
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: "Home",
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.folder_open_outlined),
                    selectedIcon: Icon(Icons.folder_open),
                    label: "Sources",
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: "Settings",
                  ),
                ],
              ),
            ),
    );
  }
}
