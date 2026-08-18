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
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/domain/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late AccountRepository accounts;
  late TransactionRepository transactions;
  late LineItemRepository lineItems;
  late CategoryRepository categories;
  late MonthlyCategoryReportService service;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_report_');
    isar = await openAppIsar(directory: tempDir.path);
    final sync = LocalSyncAdapter(isar);
    accounts = AccountRepository(isar, sync);
    transactions = TransactionRepository(isar, sync);
    lineItems = LineItemRepository(isar, sync, transactions);
    categories = CategoryRepository(isar, sync, transactions);
    service = MonthlyCategoryReportService(
      transactions,
      lineItems,
      categories,
      accounts,
    );
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<Account> account({String name = 'Giro'}) => accounts.save(
    Account()
      ..name = name
      ..type = AccountType.giro
      ..openingBalanceCents = 0
      ..openingDate = DateTime(2026, 1, 1),
  );

  Future<Category> category(String name, {String? parentUuid}) =>
      categories.save(
        Category()
          ..name = name
          ..parentUuid = parentUuid,
      );

  Future<Transaction> booking({
    required String accountUuid,
    int amountCents = -4732,
    String? categoryUuid,
    DateTime? bookingDate,
    String description = 'REWE',
  }) => transactions.save(
    Transaction()
      ..accountUuid = accountUuid
      ..amountCents = amountCents
      ..categoryUuid = categoryUuid
      ..bookingDate = bookingDate ?? DateTime(2026, 8, 12)
      ..description = description,
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

  Future<MonthlyCategoryReport> report({
    int year = 2026,
    int month = 8,
    String? accountUuid,
    ReportDirection direction = ReportDirection.expenses,
  }) => service.compute(
    year: year,
    month: month,
    accountUuid: accountUuid,
    direction: direction,
  );

  test('a month without bookings yields an empty report', () async {
    await account();

    final result = await report();

    expect(result.isEmpty, isTrue);
    expect(result.rows, isEmpty);
    expect(result.totalCents, 0);
    expect(result.uncategorizedCents, 0);
  });

  test('a booking without positions counts under its own category', () async {
    final giro = await account();
    final food = await category('Lebensmittel');
    await booking(accountUuid: giro.uuid, categoryUuid: food.uuid);

    final result = await report();

    expect(result.rows, hasLength(1));
    expect(result.rows.single.name, 'Lebensmittel');
    expect(result.rows.single.ownCents, 4732);
    expect(result.rows.single.rollupCents, 4732);
    expect(result.rows.single.depth, 0);
    expect(result.rows.single.parentCategoryUuid, isNull);
    expect(result.totalCents, 4732);
  });

  test('positions replace their booking as the counted unit', () async {
    final giro = await account();
    final food = await category('Lebensmittel');
    final drinks = await category('Getränke');
    final parent = await booking(
      accountUuid: giro.uuid,
      amountCents: -1000,
      categoryUuid: food.uuid,
    );
    await position(
      transactionUuid: parent.uuid,
      amountCents: -400,
      categoryUuid: drinks.uuid,
    );
    await position(transactionUuid: parent.uuid, amountCents: -600);

    final result = await report();

    expect(result.rowFor(drinks.uuid)!.ownCents, 400);
    expect(result.rowFor(food.uuid)!.ownCents, 600);
    expect(result.totalCents, 1000);
  });

  test('a soft-deleted position drops out of the aggregate', () async {
    final giro = await account();
    final food = await category('Lebensmittel');
    final parent = await booking(
      accountUuid: giro.uuid,
      amountCents: -1000,
      categoryUuid: food.uuid,
    );
    await position(transactionUuid: parent.uuid, amountCents: -600);
    final dropped = await position(
      transactionUuid: parent.uuid,
      amountCents: -400,
    );
    await lineItems.softDelete(dropped.uuid);

    final result = await report();

    expect(result.rowFor(food.uuid)!.ownCents, 600);
    expect(result.totalCents, 600);
  });

  test('child amounts roll up into the parent, own stays separate', () async {
    final giro = await account();
    final food = await category('Lebensmittel');
    final drinks = await category('Getränke', parentUuid: food.uuid);
    await booking(
      accountUuid: giro.uuid,
      amountCents: -1000,
      categoryUuid: food.uuid,
    );
    await booking(
      accountUuid: giro.uuid,
      amountCents: -250,
      categoryUuid: drinks.uuid,
      description: 'Kiosk',
    );

    final result = await report();

    final parentRow = result.rowFor(food.uuid)!;
    expect(parentRow.ownCents, 1000);
    expect(parentRow.rollupCents, 1250);
    expect(parentRow.parentCategoryUuid, isNull);

    final childRow = result.rowFor(drinks.uuid)!;
    expect(childRow.rollupCents, 250);
    expect(childRow.depth, 1);
    expect(childRow.parentCategoryUuid, food.uuid);
    expect(result.hasChildren(food.uuid), isTrue);
    expect(result.childrenOf(food.uuid).single.categoryUuid, drinks.uuid);
  });

  test('rows come back sorted by rollup descending', () async {
    final giro = await account();
    final small = await category('Klein');
    final big = await category('Groß');
    await booking(
      accountUuid: giro.uuid,
      amountCents: -100,
      categoryUuid: small.uuid,
    );
    await booking(
      accountUuid: giro.uuid,
      amountCents: -900,
      categoryUuid: big.uuid,
      description: 'Miete',
    );

    final result = await report();

    expect(result.rows.map((row) => row.name), ['Groß', 'Klein']);
  });

  test('an uncategorized booking lands in its own bucket', () async {
    final giro = await account();
    final food = await category('Lebensmittel');
    await booking(
      accountUuid: giro.uuid,
      amountCents: -500,
      categoryUuid: food.uuid,
    );
    await booking(
      accountUuid: giro.uuid,
      amountCents: -300,
      description: 'Unbekannt',
    );

    final result = await report();

    expect(result.uncategorizedCents, 300);
    expect(result.categorizedCents, 500);
    expect(result.totalCents, 800);
    expect(result.rows, hasLength(1));
  });

  test('a category uuid pointing nowhere counts as uncategorized', () async {
    final giro = await account();
    await booking(accountUuid: giro.uuid, categoryUuid: 'gone');

    final result = await report();

    expect(result.uncategorizedCents, 4732);
    expect(result.rows, isEmpty);
  });

  test('an archived category still carries its amounts', () async {
    final giro = await account();
    final food = await category('Lebensmittel');
    // Archiving first is the only legal order: `delete` refuses a category that
    // still has bookings, so this state can only be reached the other way round.
    await categories.delete(food.uuid);
    await booking(
      accountUuid: giro.uuid,
      amountCents: -500,
      categoryUuid: food.uuid,
    );

    final result = await report();

    expect(result.rowFor(food.uuid)!.rollupCents, 500);
  });

  test('direction splits expenses from income', () async {
    final giro = await account();
    final food = await category('Lebensmittel');
    final salary = await category('Gehalt');
    await booking(
      accountUuid: giro.uuid,
      amountCents: -500,
      categoryUuid: food.uuid,
    );
    await booking(
      accountUuid: giro.uuid,
      amountCents: 250000,
      categoryUuid: salary.uuid,
      description: 'Lohn',
    );

    final expenses = await report();
    expect(expenses.rows.map((row) => row.name), ['Lebensmittel']);
    expect(expenses.totalCents, 500);

    final income = await report(direction: ReportDirection.income);
    expect(income.rows.map((row) => row.name), ['Gehalt']);
    expect(income.totalCents, 250000);
  });

  test('an account filter excludes the other account', () async {
    final giro = await account();
    final second = await account(name: 'Zweitkonto');
    final food = await category('Lebensmittel');
    await booking(
      accountUuid: giro.uuid,
      amountCents: -500,
      categoryUuid: food.uuid,
    );
    await booking(
      accountUuid: second.uuid,
      amountCents: -700,
      categoryUuid: food.uuid,
      description: 'Aldi',
    );

    expect((await report()).totalCents, 1200);
    expect((await report(accountUuid: giro.uuid)).totalCents, 500);
    expect((await report(accountUuid: second.uuid)).totalCents, 700);
  });

  test('an archived account drops out of the all-accounts report', () async {
    final giro = await account();
    final archived = await account(name: 'Altkonto');
    final food = await category('Lebensmittel');
    await booking(
      accountUuid: giro.uuid,
      amountCents: -500,
      categoryUuid: food.uuid,
    );
    await booking(
      accountUuid: archived.uuid,
      amountCents: -700,
      categoryUuid: food.uuid,
      description: 'Alt',
    );
    await accounts.softDelete(archived.uuid);

    expect((await report()).totalCents, 500);
  });

  test('neighbouring months stay out of scope', () async {
    final giro = await account();
    final food = await category('Lebensmittel');
    await booking(
      accountUuid: giro.uuid,
      amountCents: -100,
      categoryUuid: food.uuid,
      bookingDate: DateTime(2026, 7, 31, 23, 59),
    );
    await booking(
      accountUuid: giro.uuid,
      amountCents: -200,
      categoryUuid: food.uuid,
      bookingDate: DateTime(2026, 8, 1),
      description: 'Monatsanfang',
    );
    await booking(
      accountUuid: giro.uuid,
      amountCents: -400,
      categoryUuid: food.uuid,
      bookingDate: DateTime(2026, 8, 31, 23, 59),
      description: 'Monatsende',
    );
    await booking(
      accountUuid: giro.uuid,
      amountCents: -800,
      categoryUuid: food.uuid,
      bookingDate: DateTime(2026, 9, 1),
      description: 'Folgemonat',
    );

    expect((await report()).totalCents, 600);
  });

  test('a soft-deleted booking is not counted', () async {
    final giro = await account();
    final food = await category('Lebensmittel');
    final dropped = await booking(
      accountUuid: giro.uuid,
      amountCents: -500,
      categoryUuid: food.uuid,
    );
    await transactions.softDelete(dropped.uuid);

    expect((await report()).isEmpty, isTrue);
  });
}
