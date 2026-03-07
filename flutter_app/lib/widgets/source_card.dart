import 'package:flutter/material.dart';

import '../models/rag_source.dart';
import '../models/sync_schedule.dart';
import '../utils/date_formatters.dart';

class SourceCard extends StatelessWidget {
  final RagSource source;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onUploadFiles;
  final VoidCallback onUploadFolder;
  final VoidCallback onSync;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onSchedule;
  final SyncSchedule? schedule;

  const SourceCard({
    super.key,
    required this.source,
    required this.selected,
    required this.onSelect,
    required this.onUploadFiles,
    required this.onUploadFolder,
    required this.onSync,
    required this.onRename,
    required this.onDelete,
    required this.onSchedule,
    this.schedule,
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
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'rename') onRename();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Rename'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text('Delete', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
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
              if (schedule != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: schedule!.enabled
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${schedule!.frequencyLabel}${schedule!.enabled ? "" : " (paused)"}",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: schedule!.enabled
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Next: ${formatIsoDate(schedule!.nextRunAt)}",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
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
                  OutlinedButton.icon(
                    onPressed: onSchedule,
                    icon: Icon(schedule != null ? Icons.schedule : Icons.schedule_outlined),
                    label: const Text("Schedule"),
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
