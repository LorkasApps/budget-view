import 'ocr_service.dart';

/// One position the parser proposes. The user reviews these before they become
/// `LineItem`s; ticket 018 owns the heuristics that fill them.
class LineItemCandidate {
  const LineItemCandidate({
    required this.description,
    required this.amountCents,
    this.quantity,
    this.unitPriceCents,
  });

  final String description;

  /// Signed like the parent booking — the parser is told which sign to use.
  final int amountCents;

  final double? quantity;
  final int? unitPriceCents;
}

abstract interface class ReceiptLineItemParser {
  /// [transactionSign] is `-1` for an expense, `1` for income.
  List<LineItemCandidate> parse(
    OcrResult result, {
    required int transactionSign,
  });
}

/// Proposes nothing — placeholder until ticket 018 lands the heuristics.
class NoReceiptLineItemParser implements ReceiptLineItemParser {
  const NoReceiptLineItemParser();

  @override
  List<LineItemCandidate> parse(
    OcrResult result, {
    required int transactionSign,
  }) =>
      const [];
}
