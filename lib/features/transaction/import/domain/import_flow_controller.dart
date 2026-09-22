import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../import/data/imported_source.dart';
import '../../../import/data/imported_source_kind.dart';
import '../../../import/domain/content_hash.dart';
import '../../../import/domain/import_providers.dart';
import '../../../tagging/data/tagging_rule.dart';
import '../../../tagging/domain/tagging_providers.dart';
import '../../../tagging/domain/tagging_suggest_service.dart';
import '../../data/transaction.dart';
import '../../domain/dedupe_hash.dart';
import '../../domain/transaction_providers.dart';
import '../candidate_conversion.dart';
import '../pdf/parse_result.dart';
import 'merchant_extraction.dart';
import '../pdf/pdf_parser.dart';
import '../pdf/pdf_parser_providers.dart';
import '../pdf/pdf_parser_registry.dart';

/// One parsed row as shown in the preview, after any user edits.
@immutable
class ImportRow {
  const ImportRow({
    required this.bookingDate,
    required this.amountCents,
    required this.description,
    required this.counterparty,
    this.merchant = '',
    this.categoryUuid,
    this.categorySuggested = false,
    this.kind = TransactionKind.regular,
    this.included = true,
  });

  ImportRow.fromCandidate(ParsedTransactionCandidate candidate)
      : bookingDate = candidate.bookingDate,
        amountCents = candidate.amountCents,
        description = candidate.description,
        counterparty = candidate.counterparty ?? '',
        merchant = candidate.merchant ?? '',
        categoryUuid = null,
        categorySuggested = false,
        kind = TransactionKind.regular,
        included = true;

  final DateTime bookingDate;
  final int amountCents;
  final String description;
  final String counterparty;

  /// The shop behind a collective payer, read out of the purpose text on parse.
  /// Empty for every ordinary row (ticket 047).
  final String merchant;

  /// What the suggestion for this row keys on — mirrors `Transaction.taggingKey`,
  /// so the preview offers what the booking will later learn.
  String get taggingKey => merchant.isEmpty ? counterparty : merchant;

  /// Null while uncategorized — imported rows are allowed to stay that way.
  final String? categoryUuid;

  /// True while [categoryUuid] came from a tagging rule and nobody overrode it.
  /// Travels into `Transaction.categoryAutoSuggested` on persist, which is what
  /// keeps the learn hook from reinforcing its own guess.
  final bool categorySuggested;

  /// Marked while importing is where the user still knows that a row moved money
  /// to another own account (ticket 032).
  final TransactionKind kind;

  final bool included;

  /// Same hash the repository will store, computed before anything is saved so
  /// the preview can warn.
  String get dedupeHash => dedupeHashOf(
        amountCents: amountCents,
        bookingDate: bookingDate,
        counterparty: counterparty,
      );

  ParsedTransactionCandidate toCandidate() => ParsedTransactionCandidate(
        bookingDate: bookingDate,
        amountCents: amountCents,
        description: description,
        counterparty: counterparty,
        merchant: merchant.isEmpty ? null : merchant,
      );

  /// Separate from [copyWith] because copyWith cannot express "set back to
  /// null", and clearing a category has to be possible.
  ImportRow withCategory(String? uuid, {bool suggested = false}) {
    return ImportRow(
      bookingDate: bookingDate,
      amountCents: amountCents,
      description: description,
      counterparty: counterparty,
      merchant: merchant,
      categoryUuid: uuid,
      categorySuggested: suggested,
      kind: kind,
      included: included,
    );
  }

  ImportRow copyWith({
    DateTime? bookingDate,
    int? amountCents,
    String? description,
    String? counterparty,
    TransactionKind? kind,
    bool? included,
  }) {
    return ImportRow(
      bookingDate: bookingDate ?? this.bookingDate,
      amountCents: amountCents ?? this.amountCents,
      description: description ?? this.description,
      counterparty: counterparty ?? this.counterparty,
      merchant: merchant,
      categoryUuid: categoryUuid,
      categorySuggested: categorySuggested,
      kind: kind ?? this.kind,
      included: included ?? this.included,
    );
  }
}

@immutable
class ImportSummary {
  const ImportSummary({
    required this.imported,
    required this.skipped,
    required this.warnings,
  });

  final int imported;
  final int skipped;
  final int warnings;
}

@immutable
class ImportFlowState {
  const ImportFlowState({
    this.fileName,
    this.contentHash = '',
    this.documentMatches = const [],
    this.targetAccountUuid,
    this.ranking = const [],
    this.selectedParserId,
    this.rows = const [],
    this.rowMatches = const {},
    this.rowMirrorMatches = const {},
    this.keepBothLegRows = const {},
    this.rowSuggestions = const {},
    this.intraBatchDuplicates = const {},
    this.warnings = const [],
    this.summary,
    this.busy = false,
    this.error = '',
  });

  final String? fileName;

  /// SHA-256 of the picked document, kept so the ImportedSource row can record it.
  final String contentHash;

  /// Earlier imports of this very document. Non-empty means "seen before".
  final List<ImportedSource> documentMatches;

  final String? targetAccountUuid;
  final List<PdfParserRanking> ranking;
  final String? selectedParserId;
  final List<ImportRow> rows;

  /// Row index → already-persisted bookings with the same hash on the target
  /// account.
  final Map<int, List<Transaction>> rowMatches;

  /// Row index → mirror legs the app booked itself that this row may be the
  /// bank's record of (ticket 048). Only filled for rows the hash layer found
  /// nothing for: once a leg has been replaced it carries the bank's fields and
  /// hashes like the row, so the ordinary duplicate path owns it from then on.
  final Map<int, List<Transaction>> rowMirrorMatches;

  /// Row indexes the user chose `Beide behalten` for. A decision about how to
  /// persist rather than a property of the booking, so it stays here instead of
  /// on [ImportRow] — nothing of it travels into the `Transaction`.
  final Set<int> keepBothLegRows;

  /// Row index → categories learned for that row's counterparty, strongest
  /// first. Derived display data, so it sits next to [rowMatches] rather than on
  /// the row, which stays a description of the booking.
  final Map<int, List<CategorySuggestion>> rowSuggestions;

  /// Row indexes that duplicate another row within this same document.
  final Set<int> intraBatchDuplicates;

  final List<String> warnings;
  final ImportSummary? summary;
  final bool busy;
  final String error;

  bool get hasDocument => fileName != null;

  bool get documentSeenBefore => documentMatches.isNotEmpty;

  int get includedCount => rows.where((row) => row.included).length;

  /// Whether this row looks like the bank's own record of a mirror leg, and the
  /// user therefore has a replace-or-keep decision to make.
  bool hasMirrorMatch(int index) =>
      (rowMirrorMatches[index] ?? const []).isNotEmpty;

  /// The leg a `Ersetzen` would write onto. Null when the row has no match.
  Transaction? mirrorLegFor(int index) {
    final found = rowMirrorMatches[index] ?? const <Transaction>[];
    return found.isEmpty ? null : found.first;
  }

  /// The hash layer's verdict: an already-booked row with the same hash, or a
  /// second copy of this row inside the same document.
  bool hasHashDuplicate(int index) =>
      (rowMatches[index] ?? const []).isNotEmpty ||
      intraBatchDuplicates.contains(index);

  /// Both layers count towards the header, but they never mark the same row: a
  /// mirror match is only looked for where the hash layer found nothing.
  bool isSuspicious(int index) =>
      hasHashDuplicate(index) || hasMirrorMatch(index);

  int get suspiciousCount =>
      List.generate(rows.length, (index) => index).where(isSuspicious).length;

  int get newCount => rows.length - suspiciousCount;

  ImportFlowState copyWith({
    List<ImportedSource>? documentMatches,
    String? targetAccountUuid,
    List<PdfParserRanking>? ranking,
    String? selectedParserId,
    List<ImportRow>? rows,
    Map<int, List<Transaction>>? rowMatches,
    Map<int, List<Transaction>>? rowMirrorMatches,
    Set<int>? keepBothLegRows,
    Map<int, List<CategorySuggestion>>? rowSuggestions,
    Set<int>? intraBatchDuplicates,
    List<String>? warnings,
    ImportSummary? summary,
    bool? busy,
    String? error,
  }) {
    return ImportFlowState(
      fileName: fileName,
      contentHash: contentHash,
      documentMatches: documentMatches ?? this.documentMatches,
      targetAccountUuid: targetAccountUuid ?? this.targetAccountUuid,
      ranking: ranking ?? this.ranking,
      selectedParserId: selectedParserId ?? this.selectedParserId,
      rows: rows ?? this.rows,
      rowMatches: rowMatches ?? this.rowMatches,
      rowMirrorMatches: rowMirrorMatches ?? this.rowMirrorMatches,
      keepBothLegRows: keepBothLegRows ?? this.keepBothLegRows,
      rowSuggestions: rowSuggestions ?? this.rowSuggestions,
      intraBatchDuplicates: intraBatchDuplicates ?? this.intraBatchDuplicates,
      warnings: warnings ?? this.warnings,
      summary: summary ?? this.summary,
      busy: busy ?? this.busy,
      error: error ?? this.error,
    );
  }
}

/// Drives one PDF import: hash the document, rank parsers, parse, let the user
/// curate rows, persist.
///
/// The raw bytes stay in this controller and nowhere else, so tearing the flow
/// down drops them; they are never written to disk.
class ImportFlowController extends AutoDisposeNotifier<ImportFlowState> {
  Uint8List? _bytes;

  @override
  ImportFlowState build() {
    ref.onDispose(() => _bytes = null);
    return const ImportFlowState();
  }

  PdfParser? get selectedParser {
    final parserId = state.selectedParserId;
    if (parserId == null) return null;
    for (final match in state.ranking) {
      if (match.parser.id == parserId) return match.parser;
    }
    return null;
  }

  Future<void> loadDocument(Uint8List bytes, {required String fileName}) async {
    _bytes = bytes;
    final target = state.targetAccountUuid;
    state = ImportFlowState(
      fileName: fileName,
      targetAccountUuid: target,
      busy: true,
    );

    final contentHash = computeContentHash(bytes);
    final documentMatches = await ref
        .read(duplicateCheckerProvider)
        .findDocumentMatches(contentHash);
    final ranking = await ref.read(pdfParserRegistryProvider).rank(bytes);

    state = ImportFlowState(
      fileName: fileName,
      contentHash: contentHash,
      documentMatches: documentMatches,
      targetAccountUuid: target,
      ranking: ranking,
      selectedParserId: ranking.isEmpty ? null : ranking.first.parser.id,
    );
  }

  void selectParser(String parserId) {
    state = state.copyWith(selectedParserId: parserId);
  }

  /// Target account drives duplicate scoping, so changing it re-runs the check.
  Future<void> setTargetAccount(String accountUuid) async {
    state = state.copyWith(targetAccountUuid: accountUuid);
    await _recheckDuplicates();
  }

  Future<void> parseDocument() async {
    final parser = selectedParser;
    final bytes = _bytes;
    if (parser == null || bytes == null) return;

    state = state.copyWith(busy: true, error: '');
    try {
      final result = await parser.parse(bytes);
      state = state.copyWith(
        // The merchant is read here, after parsing: a purpose text has the same
        // shape whatever bank printed it, while the column it came from does not,
        // so a second parser inherits this for free (ticket 047).
        rows: [
          for (final candidate in result.transactions)
            ImportRow.fromCandidate(
              candidate.withMerchant(
                extractMerchant(
                  candidate.description,
                  counterparty: candidate.counterparty,
                ),
              ),
            ),
        ],
        warnings: result.warnings,
        rowMatches: const {},
        rowMirrorMatches: const {},
        keepBothLegRows: const {},
        rowSuggestions: const {},
        intraBatchDuplicates: const {},
        busy: false,
      );
      await _recheckDuplicates();
      await _applySuggestions();
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Parsen fehlgeschlagen: $e');
    }
  }

  void toggleRow(int index) {
    final rows = [...state.rows];
    rows[index] = rows[index].copyWith(included: !rows[index].included);
    state = state.copyWith(rows: rows);
  }

  Future<void> editRow(
    int index, {
    DateTime? bookingDate,
    int? amountCents,
    String? description,
    String? counterparty,
  }) async {
    final rows = [...state.rows];
    rows[index] = rows[index].copyWith(
      bookingDate: bookingDate,
      amountCents: amountCents,
      description: description,
      counterparty: counterparty,
    );
    state = state.copyWith(rows: rows);

    // An edit can move a row onto or off a duplicate hash.
    await _recheckDuplicates();
    // A changed counterparty changes what the rules suggest for the row.
    await _applySuggestions();
  }

  void setRowKind(int index, TransactionKind kind) {
    final rows = [...state.rows];
    rows[index] = rows[index].copyWith(kind: kind);
    state = state.copyWith(rows: rows);
  }

  /// `Ersetzen` versus `Beide behalten` for a row that met a mirror leg.
  /// Replacing is the default, so this only ever records the exception.
  void setKeepBothLegs(int index, bool keepBoth) {
    final chosen = {...state.keepBothLegRows};
    if (keepBoth) {
      chosen.add(index);
    } else {
      chosen.remove(index);
    }
    state = state.copyWith(keepBothLegRows: chosen);
  }

  void setRowCategory(int index, String? categoryUuid) {
    final rows = [...state.rows];
    rows[index] = rows[index].withCategory(categoryUuid);
    state = state.copyWith(rows: rows);
  }

  /// Bulk-assigns to every row, included or not — the user is categorising the
  /// statement, not the selection.
  void setCategoryForAll(String? categoryUuid) {
    state = state.copyWith(
      rows: [
        for (final row in state.rows) row.withCategory(categoryUuid),
      ],
    );
  }

  Future<void> persist() async {
    final accountUuid = state.targetAccountUuid;
    // Indexes rather than rows: the mirror decision is keyed on the position.
    final included = [
      for (var index = 0; index < state.rows.length; index++)
        if (state.rows[index].included) index,
    ];
    if (accountUuid == null || included.isEmpty) return;

    state = state.copyWith(busy: true, error: '');
    final repository = ref.read(transactionRepositoryProvider);
    final learn = ref.read(taggingLearnServiceProvider);
    for (final index in included) {
      final row = state.rows[index];
      final mirror =
          state.keepBothLegRows.contains(index) ? null : state.mirrorLegFor(index);
      final transaction = mirror == null
          ? (candidateToTransaction(row.toCandidate(), accountUuid: accountUuid)
            ..categoryUuid = row.categoryUuid
            ..categoryAutoSuggested = row.categorySuggested
            ..kind = row.kind)
          : _takeBankFields(mirror, row);
      await repository.save(transaction);
      // A hand-picked category makes the statement a bulk teaching opportunity;
      // `learnFrom` skips the rows that only carry the machine's own guess.
      await learn.learnFrom(transaction);
    }

    await ref.read(importedSourceRepositoryProvider).save(
          ImportedSource()
            ..kind = ImportedSourceKind.pdf
            ..contentHashSha256 = state.contentHash
            ..filename = state.fileName ?? ''
            ..importedAt = DateTime.now()
            ..transactionsProduced = included.length
            ..note = state.documentSeenBefore
                ? 'Erneuter Import trotz Warnung'
                : null,
        );

    _bytes = null;
    state = state.copyWith(
      busy: false,
      summary: ImportSummary(
        imported: included.length,
        skipped: state.rows.length - included.length,
        warnings: state.warnings.length,
      ),
    );
  }

  /// `Ersetzen`: the bank's facts for this account overwrite the mirror leg,
  /// while everything the user put on it stays, as does the pair itself.
  ///
  /// The other leg is deliberately left alone. Mirroring amount and date is a
  /// rule for form edits: money leaves on one day and arrives on another, and if
  /// the legs differ by a fee the bank is the truth per leg.
  Transaction _takeBankFields(Transaction leg, ImportRow row) {
    return leg
      ..description = row.description
      ..counterparty = row.counterparty
      // Derived from the description that just changed, so leaving the old value
      // would describe the wrong text.
      ..merchant = row.merchant
      ..amountCents = row.amountCents
      ..bookingDate = row.bookingDate;
  }

  /// Fills every row that carries no hand-picked category with the strongest
  /// rule for its counterparty, and records the alternatives for the sheet.
  ///
  /// Rows the user categorised are left alone; a row whose counterparty lost
  /// its rules gives its suggested category back up.
  Future<void> _applySuggestions() async {
    final rows = state.rows;
    if (rows.isEmpty) return;

    final service = ref.read(taggingSuggestServiceProvider);
    // A statement repeats the same payees, and each lookup is a query.
    final cache = <String, List<CategorySuggestion>>{};
    final suggestions = <int, List<CategorySuggestion>>{};
    final updated = [...rows];

    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final found = cache[row.taggingKey] ??= await service.suggest(
        row.taggingKey,
        matchField: TaggingMatchField.counterparty,
      );
      if (found.isNotEmpty) suggestions[index] = found;

      if (row.categoryUuid != null && !row.categorySuggested) continue;
      updated[index] = found.isEmpty
          ? row.withCategory(null)
          : row.withCategory(found.first.categoryUuid, suggested: true);
    }

    state = state.copyWith(rows: updated, rowSuggestions: suggestions);
  }

  /// Recomputes both duplicate layers over the current rows. Cheap enough to
  /// re-run on every edit: one indexed query per row plus an in-memory grouping.
  Future<void> _recheckDuplicates() async {
    final accountUuid = state.targetAccountUuid;
    final rows = state.rows;
    if (rows.isEmpty) return;

    final matches = <int, List<Transaction>>{};
    final mirrorMatches = <int, List<Transaction>>{};
    if (accountUuid != null) {
      final checker = ref.read(duplicateCheckerProvider);
      for (var index = 0; index < rows.length; index++) {
        final found = await checker.findTransactionMatches(
          rows[index].dedupeHash,
          accountUuid: accountUuid,
        );
        if (found.isNotEmpty) {
          matches[index] = found;
          // The hash layer already owns this row. A leg replaced in an earlier
          // run now carries the bank's fields and therefore hashes like the row,
          // so offering `Ersetzen` again would re-ask a settled question.
          continue;
        }
        final mirrors = await checker.findMirrorLegMatches(
          accountUuid: accountUuid,
          amountCents: rows[index].amountCents,
          bookingDate: rows[index].bookingDate,
        );
        if (mirrors.isNotEmpty) mirrorMatches[index] = mirrors;
      }
    }

    final seen = <String, int>{};
    final intraBatch = <int>{};
    for (var index = 0; index < rows.length; index++) {
      final hash = rows[index].dedupeHash;
      final first = seen[hash];
      if (first == null) {
        seen[hash] = index;
      } else {
        // Flag both copies: the user has to decide which one to keep.
        intraBatch.add(first);
        intraBatch.add(index);
      }
    }

    state = state.copyWith(
      rowMatches: matches,
      rowMirrorMatches: mirrorMatches,
      // An edit can move a row off its mirror leg; the choice it carried then
      // describes nothing and must not survive into persist.
      keepBothLegRows: state.keepBothLegRows
          .where((index) => mirrorMatches.containsKey(index))
          .toSet(),
      intraBatchDuplicates: intraBatch,
    );
  }
}

final importFlowProvider =
    NotifierProvider.autoDispose<ImportFlowController, ImportFlowState>(
  ImportFlowController.new,
);
