import 'ocr_service.dart';

enum LineItemParseState {
  /// Description and amount both read cleanly.
  ok,

  /// An amount without a description — needs a human look.
  ambiguous,
}

/// One position the parser proposes, before the user reviews it.
///
/// Amounts are **unsigned magnitudes**: a receipt carries no signs, the sign
/// belongs to the parent booking (ticket 015), and the scan flow applies it on
/// persist. Immutable, because the review screen holds these in a list that the
/// widget tree reads while editing.
class LineItemCandidate {
  LineItemCandidate({
    this.description = '',
    this.amountCents,
    this.quantity,
    this.unitPriceCents,
    this.rawOcrText = '',
    this.parseState = LineItemParseState.ok,
    bool? includeInSave,
    this.categoryUuid,
  }) : includeInSave =
            includeInSave ?? parseState == LineItemParseState.ok;

  final String description;
  final int? amountCents;
  final double? quantity;
  final int? unitPriceCents;

  /// The OCR row this candidate came from, kept for the unparsed case and as
  /// context while editing.
  final String rawOcrText;

  final LineItemParseState parseState;
  final bool includeInSave;

  /// Null means the position inherits the booking's category (ticket 012).
  final String? categoryUuid;

  /// Whether the repository would accept this row.
  bool get isSavable =>
      description.trim().isNotEmpty &&
      amountCents != null &&
      amountCents! > 0;

  static const Object _keep = Object();

  LineItemCandidate copyWith({
    String? description,
    int? amountCents,
    double? quantity,
    int? unitPriceCents,
    String? rawOcrText,
    LineItemParseState? parseState,
    bool? includeInSave,
    Object? categoryUuid = _keep,
  }) =>
      LineItemCandidate(
        description: description ?? this.description,
        amountCents: amountCents ?? this.amountCents,
        quantity: quantity ?? this.quantity,
        unitPriceCents: unitPriceCents ?? this.unitPriceCents,
        rawOcrText: rawOcrText ?? this.rawOcrText,
        parseState: parseState ?? this.parseState,
        includeInSave: includeInSave ?? this.includeInSave,
        categoryUuid: categoryUuid == _keep
            ? this.categoryUuid
            : categoryUuid as String?,
      );
}

/// What one pass over a receipt yielded.
///
/// [printedTotalCents] is the receipt's own total, read but never imported: it
/// is the only figure on the paper that does not depend on the row grouping, so
/// comparing it against the positions is what turns a plausible-looking parse
/// into a checked one (ticket 035).
class ReceiptParseResult {
  const ReceiptParseResult({
    required this.candidates,
    this.printedTotalCents,
  });

  final List<LineItemCandidate> candidates;
  final int? printedTotalCents;
}

abstract interface class ReceiptLineItemParser {
  /// Empty output is valid — nothing on the receipt looked like an item.
  ReceiptParseResult parse(OcrResult result);
}
