import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/features/drilldown/scan/domain/photo_scan_providers.dart';
import 'package:budget_view/features/drilldown/scan/domain/receipt_image_source.dart';
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

  test('no row exists while the flow sits in awaitingConfirm', () async {
    final container = containerWith(isar: isar);
    final transaction = await savedExpense(container);
    final controller = container.read(photoScanFlowProvider.notifier);

    await controller.startScan(
      transaction: transaction,
      source: ScanSource.gallery,
    );

    final repo = container.read(importedSourceRepositoryProvider);
    expect(await repo.findAll(), isEmpty);
  });

  test('no row exists after cancel either', () async {
    final container = containerWith(isar: isar);
    final transaction = await savedExpense(container);
    final controller = container.read(photoScanFlowProvider.notifier);

    await controller.startScan(
      transaction: transaction,
      source: ScanSource.gallery,
    );
    controller.cancel();

    final repo = container.read(importedSourceRepositoryProvider);
    expect(await repo.findAll(), isEmpty);
  });

  test(
    'confirm writes exactly one row matching the scan, note left unset',
    () async {
      final container = containerWith(isar: isar);
      final transaction = await savedExpense(container);
      final controller = container.read(photoScanFlowProvider.notifier);

      await controller.startScan(
        transaction: transaction,
        source: ScanSource.gallery,
      );
      final candidateCount =
          container.read(photoScanFlowProvider).candidates.length;
      await controller.confirm();

      final repo = container.read(importedSourceRepositoryProvider);
      final rows = await repo.findAll();
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.kind, ImportedSourceKind.photo);
      expect(row.lineItemsProduced, candidateCount);
      expect(row.transactionsProduced, 0);
      expect(row.contentHashSha256, computeContentHash(receiptBytes()));
      expect(row.note, isNull);
    },
  );

  test(
    'proceeding through a duplicate warning notes the override',
    () async {
      final container = containerWith(isar: isar);
      await seedPriorImport(container);
      final transaction = await savedExpense(container);
      final controller = container.read(photoScanFlowProvider.notifier);

      await controller.startScan(
        transaction: transaction,
        source: ScanSource.gallery,
      );
      await controller.proceedAfterWarning();
      await controller.confirm();

      final repo = container.read(importedSourceRepositoryProvider);
      final rows = await repo.findAll();
      expect(rows, hasLength(2));
      // findAll sorts newest first; the seed row was dated in the past.
      expect(rows.first.note, 'Erneuter Scan trotz Warnung');
      expect(rows.last.note, isNull);
    },
  );
}
