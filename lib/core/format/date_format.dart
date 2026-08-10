/// Formats a date as `dd.MM.yyyy` without needing intl locale data.
String formatDateDe(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d.$m.${date.year}';
}

/// Compact `dd.MM.` form for dense list rows.
String formatDateCompactDe(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d.$m.';
}
