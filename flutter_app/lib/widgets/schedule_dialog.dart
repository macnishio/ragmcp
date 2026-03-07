import 'package:flutter/material.dart';

import '../models/sync_schedule.dart';

class ScheduleDialogResult {
  final bool deleted;
  final String? frequency;
  final String? timezone;
  final bool? enabled;

  const ScheduleDialogResult.saved({
    required String this.frequency,
    required String this.timezone,
    required bool this.enabled,
  }) : deleted = false;

  const ScheduleDialogResult.deleted()
      : deleted = true,
        frequency = null,
        timezone = null,
        enabled = null;
}

class ScheduleDialog extends StatefulWidget {
  final SyncSchedule? existing;

  const ScheduleDialog({super.key, this.existing});

  @override
  State<ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<ScheduleDialog> {
  static const _frequencies = [
    ('daily_3am', 'Daily at 3:00 AM'),
    ('every_6h', 'Every 6 hours'),
    ('every_12h', 'Every 12 hours'),
    ('weekly', 'Weekly (Mon 3:00 AM)'),
    ('monthly', 'Monthly (1st 3:00 AM)'),
  ];

  static const _timezones = [
    'Asia/Tokyo',
    'UTC',
    'America/New_York',
    'America/Los_Angeles',
    'Europe/London',
    'Europe/Berlin',
    'Asia/Shanghai',
    'Asia/Seoul',
    'Australia/Sydney',
  ];

  late String _frequency;
  late String _timezone;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _frequency = widget.existing?.frequency ?? 'daily_3am';
    _timezone = widget.existing?.timezone ?? 'Asia/Tokyo';
    _enabled = widget.existing?.enabled ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return AlertDialog(
      title: Text(isEditing ? "Edit Schedule" : "Set Schedule"),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Frequency", style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              isExpanded: true,
              items: _frequencies
                  .map((f) => DropdownMenuItem(value: f.$1, child: Text(f.$2)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _frequency = v);
              },
            ),
            const SizedBox(height: 16),
            const Text("Timezone", style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _timezones.contains(_timezone) ? _timezone : 'Asia/Tokyo',
              isExpanded: true,
              items: _timezones
                  .map((tz) => DropdownMenuItem(value: tz, child: Text(tz)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _timezone = v);
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text("Enabled"),
              value: _enabled,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => _enabled = v),
            ),
            if (isEditing && widget.existing!.lastRunAt != null) ...[
              const Divider(),
              Text(
                "Last run: ${widget.existing!.lastRunAt} (${widget.existing!.lastRunStatus ?? 'unknown'})",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (widget.existing!.lastRunError != null)
                Text(
                  "Error: ${widget.existing!.lastRunError}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red),
                ),
            ],
          ],
        ),
      ),
      actions: [
        if (isEditing)
          TextButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Delete schedule?"),
                  content: const Text("This will remove the scheduled sync."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text("Delete"),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                Navigator.of(context).pop(const ScheduleDialogResult.deleted());
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            ScheduleDialogResult.saved(
              frequency: _frequency,
              timezone: _timezone,
              enabled: _enabled,
            ),
          ),
          child: const Text("Save"),
        ),
      ],
    );
  }
}
