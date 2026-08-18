/// Formats a date as `dd.MM.yyyy` without needing intl locale data.
String formatDateDe(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d.$m.${date.year}';
}

const _monthNamesDe = [
  'Januar',
  'Februar',
  'März',
  'April',
  'Mai',
  'Juni',
  'Juli',
  'August',
  'September',
  'Oktober',
  'November',
  'Dezember',
];

/// `August 2026` — month names are spelled out here rather than taken from
/// intl, which would need `initializeDateFormatting` for a non-`en` locale.
String formatMonthYearDe(int year, int month) =>
    '${_monthNamesDe[month - 1]} $year';

/// Compact `dd.MM.` form for dense list rows.
String formatDateCompactDe(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d.$m.';
}
