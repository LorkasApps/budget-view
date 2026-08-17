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
import 'photo_scan_providers.dart';
import 'receipt_image_source.dart';
import 'receipt_line_item_parser.dart';

enum PhotoScanPhase {
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
class PhotoScanFlowState {
  const PhotoScanFlowState({
    this.phase = PhotoScanPhase.idle,
    this.documentMatches = const [],
    this.candidates = const [],
    this.filename = '',
    this.holdsImage = false,
    this.lineItemsPersisted = 0,
    this.scansCompleted = 0,
    this.errorMessage,
  });

  final PhotoScanPhase phase;

  /// Earlier imports of this exact photo, newest first (ticket 009).
  final List<ImportedSource> documentMatches;

  final List<LineItemCandidate> candidates;

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
        PhotoScanPhase.capturing ||
        PhotoScanPhase.hashing ||
        PhotoScanPhase.recognizing ||
        PhotoScanPhase.parsing ||
        PhotoScanPhase.persisting =>
          true,
        _ => false,
      };

  PhotoScanFlowState copyWith({
    PhotoScanPhase? phase,
    List<ImportedSource>? documentMatches,
    List<LineItemCandidate>? candidates,
    String? filename,
    bool? holdsImage,
    int? lineItemsPersisted,
    int? scansCompleted,
    String? errorMessage,
  }) =>
      PhotoScanFlowState(
        phase: phase ?? this.phase,
        documentMatches: documentMatches ?? this.documentMatches,
        candidates: candidates ?? this.candidates,
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
class PhotoScanFlowController extends AutoDisposeNotifier<PhotoScanFlowState> {
  Uint8List? _bytes;
  String _contentHash = '';
  Transaction? _transaction;

  @override
  PhotoScanFlowState build() {
    ref.onDispose(_dropImage);
    return const PhotoScanFlowState();
  }

  /// Starts a pass. Called again for "Scan another", which keeps only the
  /// completed-pass counter.
  Future<void> startScan({
    required Transaction transaction,
    required ScanSource source,
  }) async {
    _dropImage();
    _transaction = transaction;
    state = PhotoScanFlowState(
      phase: PhotoScanPhase.capturing,
      scansCompleted: state.scansCompleted,
    );

    try {
      final captured = await ref.read(receiptImageSourceProvider).pick(source);
      if (captured == null) {
        state = state.copyWith(phase: PhotoScanPhase.cancelled);
        return;
      }

      _bytes = captured.bytes;
      state = state.copyWith(
        phase: PhotoScanPhase.hashing,
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
        phase: PhotoScanPhase.duplicateWarning,
        documentMatches: matches,
      );
    } catch (error) {
      _fail(error);
    }
  }

  /// The user kept going after the "already scanned" warning.
  Future<void> proceedAfterWarning() async {
    if (state.phase != PhotoScanPhase.duplicateWarning) return;
    try {
      await _recognize();
    } catch (error) {
      _fail(error);
    }
  }

  Future<void> _recognize() async {
    final bytes = _bytes;
    if (bytes == null) return;

    state = state.copyWith(phase: PhotoScanPhase.recognizing);
    final prepared =
        await ref.read(receiptImagePreprocessorProvider).prepare(bytes);
    // The user may have cancelled while OCR was running.
    if (_bytes == null) return;
    final recognized = await ref.read(ocrServiceProvider).recognize(prepared);
    if (_bytes == null) return;

    state = state.copyWith(phase: PhotoScanPhase.parsing);
    final sign = _transaction!.amountCents.isNegative ? -1 : 1;
    final candidates = ref.read(receiptLineItemParserProvider).parse(
          recognized,
          transactionSign: sign,
        );

    state = state.copyWith(
      phase: PhotoScanPhase.awaitingConfirm,
      candidates: candidates,
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
        state.phase != PhotoScanPhase.awaitingConfirm) {
      return;
    }

    final items = edited ?? state.candidates;
    final seenBefore = state.documentSeenBefore;
    state = state.copyWith(phase: PhotoScanPhase.persisting);

    try {
      final repository = ref.read(lineItemRepositoryProvider);
      for (final candidate in items) {
        await repository.save(
          LineItem()
            ..transactionUuid = transaction.uuid
            ..description = candidate.description
            ..amountCents = candidate.amountCents
            ..quantity = candidate.quantity
            ..unitPriceCents = candidate.unitPriceCents,
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
        phase: PhotoScanPhase.done,
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
      phase: PhotoScanPhase.cancelled,
      holdsImage: false,
      candidates: const [],
      documentMatches: const [],
    );
  }

  void _fail(Object error) {
    _dropImage();
    state = state.copyWith(
      phase: PhotoScanPhase.failed,
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
