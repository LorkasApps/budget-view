import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/features/drilldown/data/line_item.dart';
import 'package:budget_view/features/drilldown/domain/line_item_providers.dart';
import 'package:budget_view/features/drilldown/scan/domain/photo_scan_providers.dart';
import 'package:budget_view/features/drilldown/scan/domain/receipt_image_source.dart';
import 'package:budget_view/features/drilldown/scan/domain/receipt_line_item_parser.dart';
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

  Future<Transaction> savedIncome(ProviderContainer container) =>
      container.read(transactionRepositoryProvider).save(incomeTransaction());

  test('only rows the user kept and the repository would accept are saved',
      () async {
    final excluded =
        LineItemCandidate(description: 'Brot', amountCents: 249)
            .copyWith(includeInSave: false);
    final container = containerWith(
      isar: isar,
      parser: FakeReceiptLineItemParser([
        LineItemCandidate(description: 'Milch', amountCents: 119),
        excluded,
        LineItemCandidate(), // no description or amount: not savable
      ]),
    );
    final transaction = await savedExpense(container);
    final controller = container.read(photoScanFlowProvider.notifier);

    await controller.startScan(
      transaction: transaction,
      source: ScanSource.gallery,
    );
    await controller.confirm();

    final saved = await container
        .read(lineItemRepositoryProvider)
        .findByTransaction(transaction.uuid);
    final regular = saved.where((i) => i.kind == LineItemKind.regular);
    expect(regular, hasLength(1));
    expect(regular.single.description, 'Milch');
  });

  test('persisted amountCents follows the parent booking sign', () async {
    final expenseContainer = containerWith(isar: isar);
    final expense = await savedExpense(expenseContainer);
    final expenseController =
        expenseContainer.read(photoScanFlowProvider.notifier);
    await expenseController.startScan(
      transaction: expense,
      source: ScanSource.gallery,
    );
    await expenseController.confirm();
    final expenseItems = await expenseContainer
        .read(lineItemRepositoryProvider)
        .findByTransaction(expense.uuid);
    expect(
      expenseItems
          .where((i) => i.kind == LineItemKind.regular)
          .map((i) => i.amountCents)
          .toSet(),
      {-119, -249},
    );

    // A different seed than the expense pass above, so its content hash does
    // not collide and park this pass in duplicateWarning instead.
    final incomeContainer = containerWith(
      isar: isar,
      imageSource: FakeReceiptImageSource(
        CapturedReceiptImage(bytes: receiptBytes(2)),
      ),
    );
    final income = await savedIncome(incomeContainer);
    final incomeController =
        incomeContainer.read(photoScanFlowProvider.notifier);
    await incomeController.startScan(
      transaction: income,
      source: ScanSource.gallery,
    );
    await incomeController.confirm();
    final incomeItems = await incomeContainer
        .read(lineItemRepositoryProvider)
        .findByTransaction(income.uuid);
    expect(
      incomeItems
          .where((i) => i.kind == LineItemKind.regular)
          .map((i) => i.amountCents)
          .toSet(),
      {119, 249},
    );
  });

  test('categoryUuid lands on the persisted item, or stays null', () async {
    final container = containerWith(
      isar: isar,
      parser: FakeReceiptLineItemParser([
        LineItemCandidate(
          description: 'Milch',
          amountCents: 119,
          categoryUuid: 'cat-1',
        ),
        LineItemCandidate(description: 'Brot', amountCents: 249),
      ]),
    );
    final transaction = await savedExpense(container);
    final controller = container.read(photoScanFlowProvider.notifier);

    await controller.startScan(
      transaction: transaction,
      source: ScanSource.gallery,
    );
    await controller.confirm();

    final saved = await container
        .read(lineItemRepositoryProvider)
        .findByTransaction(transaction.uuid);
    final byDescription = {for (final item in saved) item.description: item};
    expect(byDescription['Milch']!.categoryUuid, 'cat-1');
    expect(byDescription['Brot']!.categoryUuid, isNull);
  });

  test('lineItemsProduced counts included rows, not every candidate',
      () async {
    final excluded =
        LineItemCandidate(description: 'Brot', amountCents: 249)
            .copyWith(includeInSave: false);
    final container = containerWith(
      isar: isar,
      parser: FakeReceiptLineItemParser([
        LineItemCandidate(description: 'Milch', amountCents: 119),
        excluded,
        LineItemCandidate(), // no description or amount: not savable
      ]),
    );
    final transaction = await savedExpense(container);
    final controller = container.read(photoScanFlowProvider.notifier);

    await controller.startScan(
      transaction: transaction,
      source: ScanSource.gallery,
    );
    await controller.confirm();

    final repo = container.read(importedSourceRepositoryProvider);
    final rows = await repo.findAll();
    expect(rows.single.lineItemsProduced, 1);
  });

  test('confirm reconciles once, leaving a restposten row behind', () async {
    final container = containerWith(isar: isar);
    final transaction = await savedExpense(container);
    final controller = container.read(photoScanFlowProvider.notifier);

    await controller.startScan(
      transaction: transaction,
      source: ScanSource.gallery,
    );
    await controller.confirm();

    final restposten = await container
        .read(lineItemRepositoryProvider)
        .findRestposten(transaction.uuid);
    expect(restposten, isNotNull);
  });
}
