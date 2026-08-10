/// Minimal money helpers. Amounts are stored as signed integer cents.
///
/// Ticket 005 layers `intl` currency formatting on top; these plain helpers
/// stay as parse/format primitives usable without locale setup.
library;

/// Parses a user-entered euro amount into signed cents.
///
/// Accepts comma or dot as decimal separator (`"12,34"`, `"12.34"`, `"-5"`).
/// Returns `null` when the input is not a valid number.
int? parseEurosToCents(String input) {
  final normalized = input.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  final value = double.tryParse(normalized);
  if (value == null) return null;
  return (value * 100).round();
}

/// Formats signed cents as a plain `"-12,34"` string (no currency symbol).
String formatCentsPlain(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final euros = abs ~/ 100;
  final rem = abs % 100;
  return '$sign$euros,${rem.toString().padLeft(2, '0')}';
}
