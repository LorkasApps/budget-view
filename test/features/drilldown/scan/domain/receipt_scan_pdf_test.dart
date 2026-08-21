import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/features/drilldown/scan/domain/ocr_service.dart';
import 'package:budget_view/features/drilldown/scan/domain/receipt_scan_flow_controller.dart';
import 'package:budget_view/features/drilldown/scan/domain/receipt_scan_providers.dart';
import 'package:budget_view/features/import/data/imported_source.dart';
import 'package:budget_view/features/import/data/imported_source_kind.dart';
import 'package:budget_view/features/import/domain/content_hash.dart';
import 'package:budget_view/features/import/domain/import_providers.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/domain/transaction_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'scan_test_support.dart';

void main() {
  late Directory tempDir;
  late Isar isar;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_scan_');
    isar = await openAppIsar(directory: tempDir.path);
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<Transaction> savedExpense(ProviderContainer container) =>
      container.read(transactionRepositoryProvider).save(expenseTransaction());

  /// A prior import of the exact bytes [pdfBytes] returns, so a fresh PDF
  /// scan's content hash collides with it.
  Future<ImportedSource> seedPriorImport(ProviderContainer container) {
    return container.read(importedSourceRepositoryProvider).save(
          ImportedSource()
            ..kind = ImportedSourceKind.receiptPdf
            ..contentHashSha256 = computeContentHash(pdfBytes())
            ..filename = 'beleg.pdf'
            ..importedAt = DateTime(2026, 8, 1)
            ..transactionsProduced = 0
            ..lineItemsProduced = 2,
        );
  }

  test(
    'no previous import runs straight through to awaitingConfirm, carrying '
    'the reader output',
    () async {
      final container = containerWith(isar: isar);
      final transaction = await savedExpense(container);
      final controller = container.read(receiptScanFlowProvider.notifier);

      await controller.startPdfScan(transaction: transaction);

      final state = container.read(receiptScanFlowProvider);
      expect(state.phase, ReceiptScanPhase.awaitingConfirm);
      expect(state.candidates.map((c) => c.description), ['Milch', 'Brot']);
      expect(state.expectedSumCents, 368);
      expect(state.filename, 'beleg.pdf');
      expect(state.kind, ImportedSourceKind.receiptPdf);
    },
  );

  test(
    'the file picker returning null leaves the flow cancelled with nothing '
    'persisted',
    () async {
      final container = containerWith(
        isar: isar,
        pdfSource: const CancellingReceiptPdfSource(),
      );
      final transaction = await savedExpense(container);
      final controller = container.read(receiptScanFlowProvider.notifier);

      await controller.startPdfScan(transaction: transaction);

      final state = container.read(receiptScanFlowProvider);
      expect(state.phase, ReceiptScanPhase.cancelled);
      final repo = container.read(importedSourceRepositoryProvider);
      expect(await repo.findAll(), isEmpty);
    },
  );

  test(
    'a PDF with no text layer fails, pointing the user at the camera instead',
    () async {
      final container = containerWith(
        isar: isar,
        pdfReader: const FakeReceiptPdfReader(null),
      );
      final transaction = await savedExpense(container);
      final controller = container.read(receiptScanFlowProvider.notifier);

      await controller.startPdfScan(transaction: transaction);

      final state = container.read(receiptScanFlowProvider);
      expect(state.phase, ReceiptScanPhase.failed);
      expect(state.errorMessage, contains('Fotografiere'));
    },
  );

  test(
    'a duplicate PDF stops at duplicateWarning; proceeding reads via the PDF '
    'reader, never OCR',
    () async {
      final container = containerWith(
        isar: isar,
        ocr: ThrowingOcrService(OcrEngineException('OCR reached from PDF')),
        parser: const ThrowingReceiptLineItemParser(),
      );
      await seedPriorImport(container);
      final transaction = await savedExpense(container);
      final controller = container.read(receiptScanFlowProvider.notifier);

      await controller.startPdfScan(transaction: transaction);
      expect(
        container.read(receiptScanFlowProvider).phase,
        ReceiptScanPhase.duplicateWarning,
      );

      await controller.proceedAfterWarning();

      final state = container.read(receiptScanFlowProvider);
      expect(state.phase, ReceiptScanPhase.awaitingConfirm);
      expect(state.candidates.map((c) => c.description), ['Milch', 'Brot']);
    },
  );

  test(
    'confirm persists the positions and writes one receiptPdf row with the '
    'picked filename',
    () async {
      final container = containerWith(isar: isar);
      final transaction = await savedExpense(container);
      final controller = container.read(receiptScanFlowProvider.notifier);

      await controller.startPdfScan(transaction: transaction);
      await controller.confirm();

      final repo = container.read(importedSourceRepositoryProvider);
      final rows = await repo.findAll();
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.kind, ImportedSourceKind.receiptPdf);
      expect(row.filename, 'beleg.pdf');
      expect(row.contentHashSha256, computeContentHash(pdfBytes()));
    },
  );
}
