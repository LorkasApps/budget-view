import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    this.included = true,
  });

  ImportRow.fromCandidate(ParsedTransactionCandidate candidate)
      : bookingDate = candidate.bookingDate,
        amountCents = candidate.amountCents,
        description = candidate.description,
        counterparty = candidate.counterparty ?? '',
        included = true;

  final DateTime bookingDate;
  final int amountCents;
  final String description;
  final String counterparty;
  final bool included;

  ParsedTransactionCandidate toCandidate() => ParsedTransactionCandidate(
        bookingDate: bookingDate,
        amountCents: amountCents,
        description: description,
        counterparty: counterparty,
      );

  ImportRow copyWith({
    DateTime? bookingDate,
    int? amountCents,
    String? description,
    String? counterparty,
    bool? included,
  }) {
    return ImportRow(
      bookingDate: bookingDate ?? this.bookingDate,
      amountCents: amountCents ?? this.amountCents,
      description: description ?? this.description,
      counterparty: counterparty ?? this.counterparty,
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
    this.ranking = const [],
    this.selectedParserId,
    this.rows = const [],
    this.warnings = const [],
    this.summary,
    this.busy = false,
    this.error = '',
  });

  final String? fileName;
  final List<PdfParserRanking> ranking;
  final String? selectedParserId;
  final List<ImportRow> rows;
  final List<String> warnings;
  final ImportSummary? summary;
  final bool busy;
  final String error;

  bool get hasDocument => fileName != null;

  int get includedCount => rows.where((row) => row.included).length;

  ImportFlowState copyWith({
    List<PdfParserRanking>? ranking,
    String? selectedParserId,
    List<ImportRow>? rows,
    List<String>? warnings,
    ImportSummary? summary,
    bool? busy,
    String? error,
  }) {
    return ImportFlowState(
      fileName: fileName,
      ranking: ranking ?? this.ranking,
      selectedParserId: selectedParserId ?? this.selectedParserId,
      rows: rows ?? this.rows,
      warnings: warnings ?? this.warnings,
      summary: summary ?? this.summary,
      busy: busy ?? this.busy,
      error: error ?? this.error,
    );
  }
}

/// Drives one PDF import: rank parsers, parse, let the user curate rows, persist.
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
    state = ImportFlowState(fileName: fileName, busy: true);

    final ranking = await ref.read(pdfParserRegistryProvider).rank(bytes);
    state = ImportFlowState(
      fileName: fileName,
      ranking: ranking,
      selectedParserId: ranking.isEmpty ? null : ranking.first.parser.id,
    );
  }

  void selectParser(String parserId) {
    state = state.copyWith(selectedParserId: parserId);
  }

  Future<void> parseDocument() async {
    final parser = selectedParser;
    final bytes = _bytes;
    if (parser == null || bytes == null) return;

    state = state.copyWith(busy: true, error: '');
    try {
      final result = await parser.parse(bytes);
      state = ImportFlowState(
        fileName: state.fileName,
        ranking: state.ranking,
        selectedParserId: state.selectedParserId,
        rows: result.transactions.map(ImportRow.fromCandidate).toList(),
        warnings: result.warnings,
      );
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Parsen fehlgeschlagen: $e');
    }
  }

  void toggleRow(int index) {
    final rows = [...state.rows];
    rows[index] = rows[index].copyWith(included: !rows[index].included);
    state = state.copyWith(rows: rows);
  }

  void editRow(
    int index, {
    DateTime? bookingDate,
    int? amountCents,
    String? description,
    String? counterparty,
  }) {
    final rows = [...state.rows];
    rows[index] = rows[index].copyWith(
      bookingDate: bookingDate,
      amountCents: amountCents,
      description: description,
      counterparty: counterparty,
    );
    state = state.copyWith(rows: rows);
  }

  Future<void> persist({required String accountUuid}) async {
    final included = state.rows.where((row) => row.included).toList();
    if (included.isEmpty) return;

    state = state.copyWith(busy: true, error: '');
    final repository = ref.read(transactionRepositoryProvider);
    for (final row in included) {
      await repository.save(
        candidateToTransaction(row.toCandidate(), accountUuid: accountUuid),
      );
    }

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
}

final importFlowProvider =
    NotifierProvider.autoDispose<ImportFlowController, ImportFlowState>(
  ImportFlowController.new,
);
