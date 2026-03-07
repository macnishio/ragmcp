import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/app_config.dart';
import '../models/rag_source.dart';
import '../services/rag_source_service.dart';
import '../widgets/source_card.dart';

class RagSourcesScreen extends StatefulWidget {
  final AppConfig config;

  const RagSourcesScreen({
    super.key,
    required this.config,
  });

  @override
  State<RagSourcesScreen> createState() => _RagSourcesScreenState();
}

class _RagSourcesScreenState extends State<RagSourcesScreen> {
  late RagSourceService _service;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();

  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<RagSource> _sources = const [];
  RagSource? _selectedSource;
  List<RagSearchResult> _searchResults = const [];
  RagAnswer? _answer;

  @override
  void initState() {
    super.initState();
    _service = RagSourceService(baseUrl: widget.config.serverUrl);
    _checkServerConnection();
  }

  Future<void> _checkServerConnection() async {
    try {
      await _service.fetchHealth();
      _refresh();
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = "サーバーに接続できません: ${widget.config.serverUrl}\nエラー: $error\n\nサーバーが起動していることを確認してください。";
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant RagSourcesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.serverUrl != widget.config.serverUrl) {
      _service = RagSourceService(baseUrl: widget.config.serverUrl);
      _checkServerConnection();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sources = await _service.fetchSources();
      if (!mounted) {
        return;
      }
      setState(() {
        _sources = sources;
        if (_selectedSource != null) {
          RagSource? selected;
          for (final item in sources) {
            if (item.sourceId == _selectedSource!.sourceId) {
              selected = item;
              break;
            }
          }
          _selectedSource = selected;
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _createSource() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("New source"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Project docs",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text("Create"),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) {
      return;
    }

    await _runBusy(() async {
      final source = await _service.createSource(name);
      await _refresh();
      if (!mounted) {
        return;
      }
      setState(() => _selectedSource = source);
    });
  }

  Future<void> _uploadFiles(RagSource source) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null) {
      return;
    }

    final files = result.files
        .where((item) => item.path != null)
        .map((item) => File(item.path!))
        .toList();
    if (files.isEmpty) {
      return;
    }

    await _runBusy(() async {
      await _service.uploadFiles(source.sourceId, files);
      await _service.syncSource(source.sourceId);
      await _refresh();
    });
  }

  Future<void> _uploadFolder(RagSource source) async {
    final directoryPath = await FilePicker.platform.getDirectoryPath();
    if (directoryPath == null) {
      return;
    }

    final files = await _collectFiles(directoryPath);
    if (files.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No files found in selected folder")),
      );
      return;
    }

    await _runBusy(() async {
      await _service.uploadFiles(
        source.sourceId,
        files,
        basePath: directoryPath,
      );
      await _service.syncSource(source.sourceId);
      await _refresh();
    });
  }

  Future<void> _sync(RagSource source) async {
    await _runBusy(() async {
      await _service.syncSource(source.sourceId);
      await _refresh();
    });
  }

  Future<void> _search() async {
    final source = _selectedSource;
    if (source == null || _searchController.text.trim().isEmpty) {
      return;
    }

    await _runBusy(() async {
      final results = await _service.searchSource(
        source.sourceId,
        _searchController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _searchResults = results;
      });
    });
  }

  Future<void> _answerQuestion() async {
    final source = _selectedSource;
    if (source == null || _questionController.text.trim().isEmpty) {
      return;
    }

    await _runBusy(() async {
      final answer = await _service.answerSource(
        source.sourceId,
        _questionController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() => _answer = answer);
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<List<File>> _collectFiles(String directoryPath) async {
    final directory = Directory(directoryPath);
    final files = <File>[];

    await for (final entry in directory.list(recursive: true, followLinks: false)) {
      if (entry is! File) {
        continue;
      }
      if (entry.path.contains("/.") || entry.path.contains("${Platform.pathSeparator}build${Platform.pathSeparator}")) {
        continue;
      }
      files.add(entry);
    }

    return files;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Sources",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : _createSource,
                icon: const Icon(Icons.add),
                label: const Text("New"),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "接続エラー",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: _busy ? null : _checkServerConnection,
                          icon: const Icon(Icons.refresh),
                          label: const Text("再試行"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_sources.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text("No sources yet. Create one and add local files."),
              ),
            )
          else
            ..._sources.map(
              (source) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SourceCard(
                  source: source,
                  selected: _selectedSource?.sourceId == source.sourceId,
                  onSelect: () => setState(() => _selectedSource = source),
                  onUploadFiles: _busy ? () {} : () => _uploadFiles(source),
                  onUploadFolder: _busy ? () {} : () => _uploadFolder(source),
                  onSync: _busy ? () {} : () => _sync(source),
                ),
              ),
            ),
          if (_sources.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildSourceSelector(theme),
          ],
          const SizedBox(height: 20),
          _buildSearchSection(theme),
          const SizedBox(height: 20),
          _buildAnswerSection(theme),
        ],
      ),
    );
  }

  Widget _buildSourceSelector(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.library_books, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Text("Search / Ask target:", style: theme.textTheme.titleSmall),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedSource?.sourceId,
                hint: const Text("Select a source"),
                items: _sources
                    .map((s) => DropdownMenuItem(
                          value: s.sourceId,
                          child: Text(s.name),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedSource = _sources.firstWhere((s) => s.sourceId == value);
                    _searchResults = const [];
                    _answer = null;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Search",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: "Search local chunks",
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy || _selectedSource == null ? null : _search,
              icon: const Icon(Icons.search),
              label: const Text("Run Search"),
            ),
            const SizedBox(height: 12),
            if (_searchResults.isEmpty)
              const Text("No search results yet.")
            else
              ..._searchResults.map(
                (result) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(result.relPath),
                  subtitle: Text(result.excerpt),
                  trailing: Text("score ${result.score}"),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Ask",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _questionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: "Ask about the indexed content",
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy || _selectedSource == null ? null : _answerQuestion,
              icon: const Icon(Icons.question_answer_outlined),
              label: const Text("Generate Answer"),
            ),
            const SizedBox(height: 12),
            if (_answer == null)
              const Text("No answer yet.")
            else ...[
              SelectableText(_answer!.answer),
              const SizedBox(height: 12),
              ..._answer!.citations.map(
                (citation) => Text("- ${citation.relPath}${citation.heading == null ? "" : " (${citation.heading})"}"),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
