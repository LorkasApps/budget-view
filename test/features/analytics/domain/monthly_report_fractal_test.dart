import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/features/account/data/account.dart';
import 'package:budget_view/features/account/data/account_type.dart';
import 'package:budget_view/features/account/domain/account_repository.dart';
import 'package:budget_view/features/analytics/domain/monthly_category_report.dart';
import 'package:budget_view/features/analytics/domain/monthly_category_report_service.dart';
import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_repository.dart';
import 'package:budget_view/features/drilldown/data/line_item.dart';
import 'package:budget_view/features/drilldown/domain/line_item_repository.dart';
import 'package:budget_view/features/drilldown/domain/restposten_reconciler.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/domain/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

/// The fractal rule (ticket 012) seen from the report: a position with its own
/// category leaves the booking's category, one without stays.
void main() {
  late Directory tempDir;
  late Isar isar;
  late TransactionRepository transactions;
  late LineItemRepository lineItems;
  late CategoryRepository categories;
  late LocalRestpostenReconciler reconciler;
  late MonthlyCategoryReportService service;
  late Account giro;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_fractal_');
    isar = await openAppIsar(directory: tempDir.path);
    final sync = LocalSyncAdapter(isar);
    final accounts = AccountRepository(isar, sync);
    transactions = TransactionRepository(isar, sync);
    lineItems = LineItemRepository(isar, sync, transactions);
    categories = CategoryRepository(isar, sync, transactions);
    reconciler = LocalRestpostenReconciler(lineItems, transactions);
    service = MonthlyCategoryReportService(
      transactions,
      lineItems,
      categories,
      accounts,
    );
    giro = await accounts.save(
      Account()
        ..name = 'Giro'
        ..type = AccountType.giro
        ..openingBalanceCents = 0
        ..openingDate = DateTime(2026, 1, 1),
    );
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<Category> category(String name, {String? parentUuid}) =>
      categories.save(
        Category()
          ..name = name
          ..parentUuid = parentUuid,
      );

  Future<Transaction> booking({
    required int amountCents,
    String? categoryUuid,
  }) => transactions.save(
    Transaction()
      ..accountUuid = giro.uuid
      ..amountCents = amountCents
      ..categoryUuid = categoryUuid
      ..bookingDate = DateTime(2026, 8, 12)
      ..description = 'REWE',
  );

  Future<LineItem> position({
    required String transactionUuid,
    required int amountCents,
    String description = 'Position',
    String? categoryUuid,
  }) => lineItems.save(
    LineItem()
      ..transactionUuid = transactionUuid
      ..amountCents = amountCents
      ..description = description
      ..categoryUuid = categoryUuid,
  );

  Future<MonthlyCategoryReport> report() => service.compute(
    year: 2026,
    month: 8,
    direction: ReportDirection.expenses,
  );

  test('an overriding position leaves the booking category', () async {
    final food = await category('Lebensmittel');
    final household = await category('Haushalt');
    final parent = await booking(amountCents: -1000, categoryUuid: food.uuid);
    await position(
      transactionUuid: parent.uuid,
      amountCents: -300,
      description: 'Spülmittel',
      categoryUuid: household.uuid,
    );
    await position(
      transactionUuid: parent.uuid,
      amountCents: -700,
      description: 'Milch',
    );

    final result = await report();

    expect(result.rowFor(household.uuid)!.ownCents, 300);
    expect(result.rowFor(food.uuid)!.ownCents, 700);
  });

  test('an override into a subtree rolls up there, not at the booking', () async {
    final food = await category('Lebensmittel');
    final drinks = await category('Getränke', parentUuid: food.uuid);
    final household = await category('Haushalt');
    final parent = await booking(
      amountCents: -1000,
      categoryUuid: household.uuid,
    );
    await position(
      transactionUuid: parent.uuid,
      amountCents: -400,
      description: 'Cola',
      categoryUuid: drinks.uuid,
    );
    await position(
      transactionUuid: parent.uuid,
      amountCents: -600,
      description: 'Putzlappen',
    );

    final result = await report();

    expect(result.rowFor(food.uuid)!.ownCents, 0);
    expect(result.rowFor(food.uuid)!.rollupCents, 400);
    expect(result.rowFor(household.uuid)!.rollupCents, 600);
  });

  test('a position of an uncategorized booking stays uncategorized', () async {
    final parent = await booking(amountCents: -1000);
    await position(transactionUuid: parent.uuid, amountCents: -1000);

    final result = await report();

    expect(result.uncategorizedCents, 1000);
    expect(result.rows, isEmpty);
  });

  test('the Restposten keeps the report total on the booking total', () async {
    final food = await category('Lebensmittel');
    final drinks = await category('Getränke');
    final parent = await booking(amountCents: -1000, categoryUuid: food.uuid);
    await position(
      transactionUuid: parent.uuid,
      amountCents: -400,
      categoryUuid: drinks.uuid,
    );
    await reconciler.reconcile(parent.uuid);

    final result = await report();

    expect(result.totalCents, 1000);
    expect(result.rowFor(drinks.uuid)!.ownCents, 400);
    // The managed row carries no category of its own, so the remainder falls
    // back to the booking's.
    expect(result.rowFor(food.uuid)!.ownCents, 600);
  });

  test('an overshooting Restposten nets against its siblings', () async {
    final food = await category('Lebensmittel');
    final drinks = await category('Getränke', parentUuid: food.uuid);
    final parent = await booking(amountCents: -1000, categoryUuid: food.uuid);
    await position(
      transactionUuid: parent.uuid,
      amountCents: -1200,
      categoryUuid: drinks.uuid,
    );
    await reconciler.reconcile(parent.uuid);

    final result = await report();

    // +200 Restposten under Lebensmittel, −1200 under Getränke: the subtree
    // still reports the booking's 10,00 €, and the row magnitudes show both.
    expect(result.rowFor(drinks.uuid)!.rollupCents, 1200);
    expect(result.rowFor(food.uuid)!.ownCents, 200);
    expect(result.rowFor(food.uuid)!.rollupCents, 1000);
    expect(result.totalCents, 1000);
  });
}
