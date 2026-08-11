import 'package:flutter/foundation.dart';

/// A transaction row extracted from a statement PDF, not yet persisted.
@immutable
class ParsedTransactionCandidate {
  const ParsedTransactionCandidate({
    required this.bookingDate,
    required this.amountCents,
    required this.description,
    this.valueDate,
    this.counterparty,
    this.raw = const {},
  });

  final DateTime bookingDate;

  /// Wertstellung, only when the statement provides it separately.
  final DateTime? valueDate;

  /// Signed: negative = expense, positive = income.
  final int amountCents;

  final String description;

  final String? counterparty;

  /// Parser-specific debug data, e.g. the raw source line.
  final Map<String, String> raw;
}

/// Outcome of one parse run over a single PDF.
@immutable
class ParseResult {
  const ParseResult({
    required this.transactions,
    this.statementBalanceCents,
    this.warnings = const [],
  });

  final List<ParsedTransactionCandidate> transactions;

  /// The statement's own end balance, for a sanity check against our own sum.
  final int? statementBalanceCents;

  /// Unparseable regions or ambiguous rows the user should review.
  final List<String> warnings;
}
