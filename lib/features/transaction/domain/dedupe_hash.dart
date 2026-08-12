import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/text/normalize.dart';
import '../data/transaction.dart';

/// SHA-256 over amount, booking day and normalised counterparty.
///
/// The date contributes as `YYYY-MM-DD` only: the same booking arriving once by
/// hand and once from a statement must hash equal even when one copy carries a
/// time component.
///
/// An empty counterparty stays empty rather than being replaced by a
/// placeholder, so unrelated bookings of the same amount on the same day do
/// collide. That is deliberate — the collision surfaces as a warning the user
/// resolves, never as an automatic rejection.
String computeDedupeHash(Transaction transaction) => dedupeHashOf(
      amountCents: transaction.amountCents,
      bookingDate: transaction.bookingDate,
      counterparty: transaction.counterparty,
    );

/// Field-level entry point, for candidates that are not `Transaction`s yet —
/// import preview rows need their hash before anything is persisted.
String dedupeHashOf({
  required int amountCents,
  required DateTime bookingDate,
  required String counterparty,
}) {
  final canonical = [
    amountCents,
    _day(bookingDate),
    normalizeForMatching(counterparty),
  ].join('|');

  return sha256.convert(utf8.encode(canonical)).toString();
}

String _day(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-$month-$day';
}
