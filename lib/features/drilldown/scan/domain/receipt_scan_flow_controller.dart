import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../import/data/imported_source.dart';
import '../../../import/data/imported_source_kind.dart';
import '../../../import/domain/content_hash.dart';
import '../../../import/domain/import_providers.dart';
import '../../../transaction/data/transaction.dart';
import '../../data/line_item.dart';
import '../../domain/line_item_providers.dart';
import '../../domain/line_item_repository.dart';
import 'ocr_service.dart';
import 'receipt_image_source.dart';
import 'receipt_line_item_parser.dart';
import 'receipt_scan_providers.dart';

enum ReceiptScanPhase {
  idle,
  capturing,
  hashing,
  duplicateWarning,
  recognizing,
  parsing,
  awaitingConfirm,
  persisting,
  done,
  cancelled,
  failed,
}

@immutable
class ReceiptScanFlowState {
  const ReceiptScanFlowState({
    this.phase = ReceiptScanPhase.idle,
    this.documentMatches = const [],
    this.candidates = const [],
    this.expectedSumCents,
    this.filename = '',
    this.holdsImage = false,
    this.lineItemsPersisted = 0,
    this.scansCompleted = 0,
    this.errorMessage,
  });

  final ReceiptScanPhase phase;

  /// Earlier imports of this exact photo, newest first (ticket 009).
  final List<ImportedSource> documentMatches;

  final List<LineItemCandidate> candidates;

  /// What the kept positions have to add up to: the receipt's printed total plus
  /// the credit rows it already accounted for (tickets 035, 033).
  final int? expectedSumCents;

  /// Display name of the pick; empty for camera captures.
  final String filename;

  /// Mirrors the controller's private byte reference, so "the bytes are gone"
  /// is observable from the UI and from a test.
  final bool holdsImage;

  final int lineItemsPersisted;

  /// Completed passes within this flow — the "Scan another" counter.
  final int scansCompleted;

  final String? errorMessage;

  bool get documentSeenBefore => documentMatches.isNotEmpty;

  bool get busy => switch (phase) {
        ReceiptScanPhase.capturing ||
        ReceiptScanPhase.hashing ||
        ReceiptScanPhase.recognizing ||
        ReceiptScanPhase.parsing ||
        ReceiptScanPhase.persisting =>
          true,
        _ => false,
      };

  ReceiptScanFlowState copyWith({
    ReceiptScanPhase? phase,
    List<ImportedSource>? documentMatches,
    List<LineItemCandidate>? candidates,
    int? expectedSumCents,
    String? filename,
    bool? holdsImage,
    int? lineItemsPersisted,
    int? scansCompleted,
    String? errorMessage,
  }) =>
      ReceiptScanFlowState(
        phase: phase ?? this.phase,
        documentMatches: documentMatches ?? this.documentMatches,
        candidates: candidates ?? this.candidates,
        expectedSumCents: expectedSumCents ?? this.expectedSumCents,
        filename: filename ?? this.filename,
        holdsImage: holdsImage ?? this.holdsImage,
        lineItemsPersisted: lineItemsPersisted ?? this.lineItemsPersisted,
        scansCompleted: scansCompleted ?? this.scansCompleted,
        errorMessage: errorMessage,
      );
}

/// Drives one receipt through capture → hash check → OCR → parse → confirm.
///
/// The photo itself never leaves memory and never reaches a repository: only
/// the extracted positions and one [ImportedSource] row survive the flow.
class ReceiptScanFlowController extends AutoDisposeNotifier<ReceiptScanFlowState> {
  Uint8List? _bytes;
  String _contentHash = '';
  Transaction? _transaction;

  @override
  ReceiptScanFlowState build() {
    ref.onDispose(_dropImage);
    return const ReceiptScanFlowState();
  }

  /// Starts a pass. Called again for "Scan another", which keeps only the
  /// completed-pass counter.
  Future<void> startScan({
    required Transaction transaction,
    required ScanSource source,
  }) async {
    _dropImage();
    _transaction = transaction;
    state = ReceiptScanFlowState(
      phase: ReceiptScanPhase.capturing,
      scansCompleted: state.scansCompleted,
    );

    try {
      final captured = await ref.read(receiptImageSourceProvider).pick(source);
      if (captured == null) {
        state = state.copyWith(phase: ReceiptScanPhase.cancelled);
        return;
      }

      _bytes = captured.bytes;
      state = state.copyWith(
        phase: ReceiptScanPhase.hashing,
        filename: captured.filename,
        holdsImage: true,
      );

      _contentHash = computeContentHash(captured.bytes);
      final matches =
          await ref.read(duplicateCheckerProvider).findDocumentMatches(
                _contentHash,
              );
      if (matches.isEmpty) {
        await _recognize();
        return;
      }
      state = state.copyWith(
        phase: ReceiptScanPhase.duplicateWarning,
        documentMatches: matches,
      );
    } catch (error) {
      _fail(error);
    }
  }

  /// The user kept going after the "already scanned" warning.
  Future<void> proceedAfterWarning() async {
    if (state.phase != ReceiptScanPhase.duplicateWarning) return;
    try {
      await _recognize();
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> _recognize() async {
    final bytes = _bytes;
    if (bytes == null) return;

    state = state.copyWith(phase: ReceiptScanPhase.recognizing);
    final prepared =
        await ref.read(receiptImagePreprocessorProvider).prepare(bytes);
    // The user may have cancelled while OCR was running.
    if (_bytes == null) return;
    final recognized = await ref.read(ocrServiceProvider).recognize(prepared);
    if (_bytes == null) return;

    state = state.copyWith(phase: ReceiptScanPhase.parsing);
    final parsed = ref.read(receiptLineItemParserProvider).parse(recognized);

    state = state.copyWith(
      phase: ReceiptScanPhase.awaitingConfirm,
      candidates: parsed.candidates,
      expectedSumCents: parsed.expectedPositionSumCents,
    );
  }

  /// Persists the reviewed positions, records the scan, discards the photo.
  ///
  /// [edited] is what ticket 018's review step hands back; without it the
  /// parser's proposal is taken as-is.
  Future<void> confirm({List<LineItemCandidate>? edited}) async {
    final transaction = _transaction;
    if (transaction == null ||
        _bytes == null ||
        state.phase != ReceiptScanPhase.awaitingConfirm) {
      return;
    }

    // Only rows the user kept, and only rows the repository would accept —
    // an unparsed row that was never completed is skipped, not rejected.
    final items = (edited ?? state.candidates)
        .where((candidate) => candidate.includeInSave && candidate.isSavable)
        .toList();
    final seenBefore = state.documentSeenBefore;
    final sign = transaction.amountCents.isNegative ? -1 : 1;
    state = state.copyWith(phase: ReceiptScanPhase.persisting);

    try {
      final repository = ref.read(lineItemRepositoryProvider);
      for (final candidate in items) {
        await repository.save(
          LineItem()
            ..transactionUuid = transaction.uuid
            ..description = candidate.description
            ..amountCents = sign * candidate.amountCents!
            ..quantity = candidate.quantity
            ..unitPriceCents = candidate.unitPriceCents
            ..categoryUuid = candidate.categoryUuid,
        );
      }
      // Fresh positions move the sum, so the managed Restposten row has to
      // follow — same rule as every other write path (see decisions.md).
      if (items.isNotEmpty) {
        await ref
            .read(restpostenReconcilerProvider)
            .reconcile(transaction.uuid);
      }

      await ref.read(importedSourceRepositoryProvider).save(
            ImportedSource()
              ..kind = ImportedSourceKind.photo
              ..contentHashSha256 = _contentHash
              ..filename = state.filename
              ..importedAt = DateTime.now()
              ..transactionsProduced = 0
              ..lineItemsProduced = items.length
              ..note = seenBefore ? 'Erneuter Scan trotz Warnung' : null,
          );

      _dropImage();
      state = state.copyWith(
        phase: ReceiptScanPhase.done,
        holdsImage: false,
        candidates: const [],
        documentMatches: const [],
        lineItemsPersisted: items.length,
        scansCompleted: state.scansCompleted + 1,
      );
    } catch (error) {
      _fail(error);
    }
  }

  /// Leaves the flow without a trace: no positions, no [ImportedSource] row.
  void cancel() {
    _dropImage();
    state = state.copyWith(
      phase: ReceiptScanPhase.cancelled,
      holdsImage: false,
      candidates: const [],
      documentMatches: const [],
    );
  }

  void _fail(Object error) {
    _dropImage();
    state = state.copyWith(
      phase: ReceiptScanPhase.failed,
      holdsImage: false,
      candidates: const [],
      documentMatches: const [],
      errorMessage: switch (error) {
        LineItemInvalid() => error.message,
        OcrEngineException() => error.message,
        _ => '$error',
      },
    );
  }

  void _dropImage() {
    _bytes = null;
    _contentHash = '';
  }
}
