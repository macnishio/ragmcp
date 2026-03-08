String toFtsQuery(String query) {
  final tokens = RegExp(r'[A-Za-z0-9_.:/-]{2,}|[\p{L}\p{N}]{2,}', unicode: true)
      .allMatches(query)
      .map((m) => m.group(0)!.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  if (tokens.isEmpty) return '';

  return tokens.map((t) => '"${t.replaceAll('"', '""')}"').join(' OR ');
}

String buildExcerpt(String content, String query) {
  final normalizedContent = content.replaceAll(RegExp(r'\s+'), ' ').trim();
  final needle = query.trim().toLowerCase();
  final lower = normalizedContent.toLowerCase();
  final index = lower.indexOf(needle);

  if (index < 0) {
    return normalizedContent.length > 240
        ? normalizedContent.substring(0, 240)
        : normalizedContent;
  }

  final start = index > 80 ? index - 80 : 0;
  final end = (index + needle.length + 140).clamp(0, normalizedContent.length);
  final excerpt = normalizedContent.substring(start, end).trim();
  return start > 0 ? '...$excerpt' : excerpt;
}
