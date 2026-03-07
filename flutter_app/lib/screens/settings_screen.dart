import 'package:flutter/material.dart';

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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
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
    );

    await widget.onSaved(config);
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Settings saved")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Local server URL",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _serverUrlController,
                  decoration: const InputDecoration(
                    hintText: "http://127.0.0.1:3001",
                  ),
                ),
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
    );
  }
}
