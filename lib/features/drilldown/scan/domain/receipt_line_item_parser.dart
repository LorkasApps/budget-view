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
    this.categorySuggested = false,
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

  /// True while [categoryUuid] came from an article rule and nobody overrode it,
  /// so the learn hook can skip its own guess at confirm (ticket 056).
  ///
  /// Transient by design, mirroring `ImportRow.categorySuggested`: a candidate
  /// never reaches the database, and the position's only other write path is the
  /// line-item sheet, where every change is by hand and therefore teaches.
  final bool categorySuggested;

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
    bool? categorySuggested,
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
        categorySuggested: categorySuggested ?? this.categorySuggested,
      );

  /// Sets the category and says where it came from in one step, so the two can
  /// never drift apart. `copyWith` alone would let a hand-picked category keep an
  /// inherited `categorySuggested` of true and teach nothing on confirm.
  LineItemCandidate withCategory(String? uuid, {bool suggested = false}) =>
      copyWith(categoryUuid: uuid, categorySuggested: suggested);
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
    this.creditCents = 0,
    this.unreadRows = const [],
  });

  final List<LineItemCandidate> candidates;
  final int? printedTotalCents;

  /// Rows that carried text but no amount the parser could use, in reading order.
  ///
  /// Kept so the review screen can show them behind a collapsed line. Ticket 035
  /// dropped such rows silently and thereby removed the only diagnostic there is:
  /// the OCR plugin has no test-VM binding, so the app itself is the sole place
  /// where raw recognised text can surface (ticket 045).
  final List<String> unreadRows;

  /// Sum of rows that reduce what was paid — returned deposits, refunds. They
  /// cannot be positions, because a `LineItem` amount carries no sign, but the
  /// printed total already accounts for them: the positions reconcile only after
  /// this is subtracted.
  final int creditCents;

  /// What the positions have to add up to for the reading to be trusted, or null
  /// when the document printed no total.
  int? get expectedPositionSumCents =>
      printedTotalCents == null ? null : printedTotalCents! + creditCents;
}

abstract interface class ReceiptLineItemParser {
  /// Empty output is valid — nothing on the receipt looked like an item.
  ReceiptParseResult parse(OcrResult result);
}
