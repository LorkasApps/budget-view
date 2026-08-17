import 'dart:typed_data';

import 'package:budget_view/core/persistence/isar_provider.dart';
import 'package:budget_view/features/drilldown/scan/domain/ocr_service.dart';
import 'package:budget_view/features/drilldown/scan/domain/photo_scan_providers.dart';
import 'package:budget_view/features/drilldown/scan/domain/receipt_image_source.dart';
import 'package:budget_view/features/drilldown/scan/domain/receipt_line_item_parser.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

/// Shared fakes and fixtures for the ticket 016 scan-flow tests. Kept in one
/// place (rather than duplicated per file) since all four suites wire the
/// same four seams; the boilerplate around `Isar` still lives in each file,
/// matching `import_flow_controller_test.dart`.

/// Deterministic bytes for a "captured photo". [seed] varies the content (and
/// therefore the SHA-256 hash) between passes in the multi-scan test.
Uint8List receiptBytes([int seed = 1]) =>
    Uint8List.fromList(List.generate(8, (i) => seed + i));

/// Returns a fixed capture. Mutable via [setNext] so a "Scan another" test can
/// swap in fresh bytes for a second pass without rebuilding the container.
class FakeReceiptImageSource implements ReceiptImageSource {
  FakeReceiptImageSource(this._next);

  CapturedReceiptImage? _next;

  void setNext(CapturedReceiptImage? image) => _next = image;

  @override
  Future<CapturedReceiptImage?> pick(ScanSource source) async => _next;
}

/// The user backed out of the camera or picker.
class CancellingReceiptImageSource implements ReceiptImageSource {
  const CancellingReceiptImageSource();

  @override
  Future<CapturedReceiptImage?> pick(ScanSource source) async => null;
}

/// Returns the bytes unchanged, keeping `compute()` and its isolate out of
/// the tests.
class IdentityReceiptImagePreprocessor implements ReceiptImagePreprocessor {
  const IdentityReceiptImagePreprocessor();

  @override
  Future<Uint8List> prepare(Uint8List bytes) async => bytes;
}

/// Recognizes a canned result regardless of input.
class FakeOcrService implements OcrService {
  const FakeOcrService([this.result = const OcrResult(fullText: 'REWE')]);

  final OcrResult result;

  @override
  Future<OcrResult> recognize(Uint8List bytes) async => result;
}

/// Proposes a fixed, mutable list of candidates regardless of the OCR input.
/// Mutable so the multi-scan test can vary the count between passes.
class FakeReceiptLineItemParser implements ReceiptLineItemParser {
  FakeReceiptLineItemParser(this.candidates);

  List<LineItemCandidate> candidates;

  @override
  List<LineItemCandidate> parse(
    OcrResult result, {
    required int transactionSign,
  }) =>
      candidates;
}

/// Two negative positions, matching an expense parent's sign.
List<LineItemCandidate> defaultCandidates() => const [
      LineItemCandidate(description: 'Milch', amountCents: -119),
      LineItemCandidate(description: 'Brot', amountCents: -249),
    ];

/// A candidate `LineItemRepository.save` must reject (empty description) —
/// used to force the controller's failure path.
LineItemCandidate invalidCandidate() =>
    const LineItemCandidate(description: '', amountCents: -100);

/// An unsaved expense booking. Callers persist it via
/// `transactionRepositoryProvider` before starting a scan against it.
Transaction expenseTransaction({
  String accountUuid = 'acc-1',
  int amountCents = -4732,
  String description = 'REWE Einkauf',
}) {
  return Transaction()
    ..accountUuid = accountUuid
    ..amountCents = amountCents
    ..bookingDate = DateTime(2026, 8, 1)
    ..description = description;
}

/// Wires a container the way the app does, with the four scan seams and the
/// duplicate/import machinery swapped for fakes or a real (test) [Isar].
/// Keeps a listener on [photoScanFlowProvider] alive, since without one the
/// `autoDispose` controller is torn down between awaits and the held bytes
/// vanish mid-test.
ProviderContainer containerWith({
  required Isar isar,
  ReceiptImageSource? imageSource,
  ReceiptImagePreprocessor? preprocessor,
  OcrService? ocr,
  ReceiptLineItemParser? parser,
}) {
  final container = ProviderContainer(
    overrides: [
      isarProvider.overrideWithValue(isar),
      receiptImageSourceProvider.overrideWithValue(
        imageSource ??
            FakeReceiptImageSource(
              CapturedReceiptImage(bytes: receiptBytes()),
            ),
      ),
      receiptImagePreprocessorProvider.overrideWithValue(
        preprocessor ?? const IdentityReceiptImagePreprocessor(),
      ),
      ocrServiceProvider.overrideWithValue(ocr ?? const FakeOcrService()),
      receiptLineItemParserProvider.overrideWithValue(
        parser ?? FakeReceiptLineItemParser(defaultCandidates()),
      ),
    ],
  );
  addTearDown(container.dispose);
  final subscription = container.listen(photoScanFlowProvider, (_, _) {});
  addTearDown(subscription.close);
  return container;
}
