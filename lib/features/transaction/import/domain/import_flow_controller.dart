import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../import/data/imported_source.dart';
import '../../../import/data/imported_source_kind.dart';
import '../../../import/domain/content_hash.dart';
import '../../../import/domain/import_providers.dart';
import '../../../tagging/domain/tagging_providers.dart';
import '../../../tagging/domain/tagging_suggest_service.dart';
import '../../data/transaction.dart';
import '../../domain/dedupe_hash.dart';
import '../../domain/transaction_providers.dart';
import '../candidate_conversion.dart';
import '../pdf/parse_result.dart';
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
        categoryUuid = null,
        categorySuggested = false,
        kind = TransactionKind.regular,
        included = true;

  final DateTime bookingDate;
  final int amountCents;
  final String description;
  final String counterparty;

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
      );

  /// Separate from [copyWith] because copyWith cannot express "set back to
  /// null", and clearing a category has to be possible.
  ImportRow withCategory(String? uuid, {bool suggested = false}) {
    return ImportRow(
      bookingDate: bookingDate,
      amountCents: amountCents,
      description: description,
      counterparty: counterparty,
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

  bool isSuspicious(int index) =>
      (rowMatches[index] ?? const []).isNotEmpty ||
      intraBatchDuplicates.contains(index);

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
        rows: result.transactions.map(ImportRow.fromCandidate).toList(),
        warnings: result.warnings,
        rowMatches: const {},
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
    final included = state.rows.where((row) => row.included).toList();
    if (accountUuid == null || included.isEmpty) return;

    state = state.copyWith(busy: true, error: '');
    final repository = ref.read(transactionRepositoryProvider);
    final learn = ref.read(taggingLearnServiceProvider);
    for (final row in included) {
      final transaction =
          candidateToTransaction(row.toCandidate(), accountUuid: accountUuid)
            ..categoryUuid = row.categoryUuid
            ..categoryAutoSuggested = row.categorySuggested
            ..kind = row.kind;
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
      final found = cache[row.counterparty] ??=
          await service.suggest(row.counterparty);
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
    if (accountUuid != null) {
      final checker = ref.read(duplicateCheckerProvider);
      for (var index = 0; index < rows.length; index++) {
        final found = await checker.findTransactionMatches(
          rows[index].dedupeHash,
          accountUuid: accountUuid,
        );
        if (found.isNotEmpty) matches[index] = found;
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
      intraBatchDuplicates: intraBatch,
    );
  }
}

final importFlowProvider =
    NotifierProvider.autoDispose<ImportFlowController, ImportFlowState>(
  ImportFlowController.new,
);
