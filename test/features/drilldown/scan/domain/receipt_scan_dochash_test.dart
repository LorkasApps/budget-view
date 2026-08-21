import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/features/drilldown/scan/domain/receipt_image_source.dart';
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

  /// A prior import of the exact bytes [receiptBytes] returns, so a fresh
  /// scan's content hash collides with it.
  Future<ImportedSource> seedPriorImport(ProviderContainer container) {
    return container.read(importedSourceRepositoryProvider).save(
          ImportedSource()
            ..kind = ImportedSourceKind.photo
            ..contentHashSha256 = computeContentHash(receiptBytes())
            ..filename = 'beleg.jpg'
            ..importedAt = DateTime(2026, 8, 1)
            ..transactionsProduced = 0
            ..lineItemsProduced = 2,
        );
  }

  test('no previous import runs straight through to awaitingConfirm',
      () async {
    final container = containerWith(isar: isar);
    final transaction = await savedExpense(container);
    final controller = container.read(receiptScanFlowProvider.notifier);

    await controller.startScan(
      transaction: transaction,
      source: ScanSource.gallery,
    );

    final state = container.read(receiptScanFlowProvider);
    expect(state.phase, ReceiptScanPhase.awaitingConfirm);
    expect(state.documentMatches, isEmpty);
  });

  test('a matching content hash parks the flow in duplicateWarning',
      () async {
    final container = containerWith(isar: isar);
    final prior = await seedPriorImport(container);
    final transaction = await savedExpense(container);
    final controller = container.read(receiptScanFlowProvider.notifier);

    await controller.startScan(
      transaction: transaction,
      source: ScanSource.gallery,
    );

    final state = container.read(receiptScanFlowProvider);
    expect(state.phase, ReceiptScanPhase.duplicateWarning);
    expect(state.documentMatches.map((m) => m.uuid), [prior.uuid]);
  });

  test('proceedAfterWarning continues on into awaitingConfirm', () async {
    final container = containerWith(isar: isar);
    await seedPriorImport(container);
    final transaction = await savedExpense(container);
    final controller = container.read(receiptScanFlowProvider.notifier);

    await controller.startScan(
      transaction: transaction,
      source: ScanSource.gallery,
    );
    await controller.proceedAfterWarning();

    final state = container.read(receiptScanFlowProvider);
    expect(state.phase, ReceiptScanPhase.awaitingConfirm);
    expect(state.candidates, isNotEmpty);
  });

  test('cancelling from duplicateWarning persists nothing', () async {
    final container = containerWith(isar: isar);
    await seedPriorImport(container);
    final transaction = await savedExpense(container);
    final controller = container.read(receiptScanFlowProvider.notifier);

    await controller.startScan(
      transaction: transaction,
      source: ScanSource.gallery,
    );
    controller.cancel();

    expect(
      container.read(receiptScanFlowProvider).phase,
      ReceiptScanPhase.cancelled,
    );
    final repo = container.read(importedSourceRepositoryProvider);
    expect(await repo.findAll(), hasLength(1));
  });
}
