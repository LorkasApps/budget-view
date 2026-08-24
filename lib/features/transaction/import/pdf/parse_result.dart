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
    this.merchant,
    this.raw = const {},
  });

  final DateTime bookingDate;

  /// Wertstellung, only when the statement provides it separately.
  final DateTime? valueDate;

  /// Signed: negative = expense, positive = income.
  final int amountCents;

  final String description;

  final String? counterparty;

  /// Who the money really went to, when a collective payer hides it in the
  /// purpose text (ticket 047). Filled after parsing, not by a parser: the shape
  /// of a purpose text is bank-independent, the column it came from is not.
  final String? merchant;

  /// Parser-specific debug data, e.g. the raw source line.
  final Map<String, String> raw;

  ParsedTransactionCandidate withMerchant(String? merchant) =>
      ParsedTransactionCandidate(
        bookingDate: bookingDate,
        amountCents: amountCents,
        description: description,
        valueDate: valueDate,
        counterparty: counterparty,
        merchant: merchant,
        raw: raw,
      );
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
