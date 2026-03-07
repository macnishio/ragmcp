class SyncSchedule {
  final String id;
  final String sourceId;
  final String frequency;
  final String timezone;
  final bool enabled;
  final String nextRunAt;
  final String? lastRunAt;
  final String? lastRunStatus;
  final String? lastRunError;
  final String createdAt;
  final String updatedAt;

  const SyncSchedule({
    required this.id,
    required this.sourceId,
    required this.frequency,
    required this.timezone,
    required this.enabled,
    required this.nextRunAt,
    required this.lastRunAt,
    required this.lastRunStatus,
    required this.lastRunError,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SyncSchedule.fromJson(Map<String, dynamic> json) {
    return SyncSchedule(
      id: (json["id"] ?? "").toString(),
      sourceId: (json["sourceId"] ?? "").toString(),
      frequency: (json["frequency"] ?? "").toString(),
      timezone: (json["timezone"] ?? "Asia/Tokyo").toString(),
      enabled: json["enabled"] == true,
      nextRunAt: (json["nextRunAt"] ?? "").toString(),
      lastRunAt: json["lastRunAt"]?.toString(),
      lastRunStatus: json["lastRunStatus"]?.toString(),
      lastRunError: json["lastRunError"]?.toString(),
      createdAt: (json["createdAt"] ?? "").toString(),
      updatedAt: (json["updatedAt"] ?? "").toString(),
    );
  }

  String get frequencyLabel {
    switch (frequency) {
      case 'daily_3am':
        return 'Daily at 3:00 AM';
      case 'every_6h':
        return 'Every 6 hours';
      case 'every_12h':
        return 'Every 12 hours';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      default:
        return frequency;
    }
  }
}
