import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../main.dart' show serverProcessService;
import '../models/app_config.dart';

class SettingsScreen extends StatefulWidget {
  final AppConfig initialConfig;
  final Future<void> Function(AppConfig config) onSaved;

  const SettingsScreen({
    super.key,
    required this.initialConfig,
    required this.onSaved,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _serverUrlController;
  late bool _useExternal;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _useExternal = widget.initialConfig.useExternalServer;
    _serverUrlController = TextEditingController(
      text: widget.initialConfig.serverUrl,
    );
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialConfig.serverUrl != widget.initialConfig.serverUrl) {
      _serverUrlController.text = widget.initialConfig.serverUrl;
    }
    if (oldWidget.initialConfig.useExternalServer != widget.initialConfig.useExternalServer) {
      _useExternal = widget.initialConfig.useExternalServer;
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final config = widget.initialConfig.copyWith(
      serverUrl: _serverUrlController.text.trim(),
      useExternalServer: _useExternal,
    );

    await widget.onSaved(config);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Settings saved")),
    );
  }

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final embedded = serverProcessService.isRunning;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          "Settings",
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 20),
        if (_isMobile)
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storage, color: theme.colorScheme.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Local mode",
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "RAG data is stored locally on this device. "
                    "No external server needed.",
                  ),
                ],
              ),
            ),
          ),
        if (!_isMobile && embedded && !_useExternal)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        "Embedded server running",
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("URL: ${serverProcessService.serverUrl}"),
                  Text("Port: ${serverProcessService.port}"),
                ],
              ),
            ),
          ),
        if (!_isMobile) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text("Use external server"),
                    subtitle: const Text("Connect to a manually started server"),
                    value: _useExternal,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _useExternal = v),
                  ),
                  if (_useExternal) ...[
                    const SizedBox(height: 12),
                    Text(
                      "Server URL",
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _serverUrlController,
                      decoration: const InputDecoration(
                        hintText: "http://127.0.0.1:3001",
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text("Save"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
