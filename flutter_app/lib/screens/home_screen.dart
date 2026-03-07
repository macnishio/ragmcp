import 'package:flutter/material.dart';

import '../models/app_config.dart';
import '../services/rag_source_service.dart';

class HomeScreen extends StatefulWidget {
  final AppConfig config;
  final VoidCallback onOpenSources;
  final VoidCallback onOpenSettings;

  const HomeScreen({
    super.key,
    required this.config,
    required this.onOpenSources,
    required this.onOpenSettings,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late RagSourceService _service;
  Map<String, dynamic>? _health;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = RagSourceService(baseUrl: widget.config.serverUrl);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.serverUrl != widget.config.serverUrl) {
      _service = RagSourceService(baseUrl: widget.config.serverUrl);
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final health = await _service.fetchHealth();
      if (!mounted) {
        return;
      }
      setState(() {
        _health = health;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            "ragmcp",
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Fully local MCP + RAG workspace",
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Server",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(widget.config.serverUrl),
                  const SizedBox(height: 12),
                  if (_loading)
                    const LinearProgressIndicator()
                  else if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    )
                  else if (_health != null)
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _MetricChip(
                          label: "sources",
                          value: "${_health!["sourceCount"] ?? 0}",
                        ),
                        _MetricChip(
                          label: "documents",
                          value: "${_health!["documentCount"] ?? 0}",
                        ),
                        _MetricChip(
                          label: "chunks",
                          value: "${_health!["chunkCount"] ?? 0}",
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: widget.onOpenSources,
                        icon: const Icon(Icons.folder_open),
                        label: const Text("Open Sources"),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: widget.onOpenSettings,
                        icon: const Icon(Icons.settings),
                        label: const Text("Settings"),
                      ),
                      OutlinedButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Refresh"),
                      ),
                    ],
                  ),
                ],
              ),
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
                    "What works now",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text("1. Create a source"),
                  const Text("2. Upload files or a folder"),
                  const Text("3. Sync local documents into SQLite"),
                  const Text("4. Search or ask questions with local citations"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text("$label: $value"),
    );
  }
}
