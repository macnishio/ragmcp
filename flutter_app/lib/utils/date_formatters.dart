String formatIsoDate(String? iso) {
  if (iso == null || iso.isEmpty) {
    return "-";
  }

  final parsed = DateTime.tryParse(iso);
  if (parsed == null) {
    return iso;
  }

  final local = parsed.toLocal();
  final month = local.month.toString().padLeft(2, "0");
  final day = local.day.toString().padLeft(2, "0");
  final hour = local.hour.toString().padLeft(2, "0");
  final minute = local.minute.toString().padLeft(2, "0");
  return "${local.year}-$month-$day $hour:$minute";
}
