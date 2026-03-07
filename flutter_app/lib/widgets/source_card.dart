import 'package:flutter/material.dart';

import '../models/rag_source.dart';
import '../utils/date_formatters.dart';

class SourceCard extends StatelessWidget {
  final RagSource source;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onUploadFiles;
  final VoidCallback onUploadFolder;
  final VoidCallback onSync;

  const SourceCard({
    super.key,
    required this.source,
    required this.selected,
    required this.onSelect,
    required this.onUploadFiles,
    required this.onUploadFolder,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      source.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(source.status),
                    backgroundColor: selected
                        ? theme.colorScheme.secondaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text("documents: ${source.documentCount}"),
                  Text("chunks: ${source.chunkCount}"),
                  Text("updated: ${formatIsoDate(source.updatedAt)}"),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onUploadFiles,
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text("Files"),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onUploadFolder,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text("Folder"),
                  ),
                  FilledButton.icon(
                    onPressed: onSync,
                    icon: const Icon(Icons.sync),
                    label: const Text("Sync"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
