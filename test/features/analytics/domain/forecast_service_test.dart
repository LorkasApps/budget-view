import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/features/account/data/account.dart';
import 'package:budget_view/features/account/data/account_type.dart';
import 'package:budget_view/features/account/domain/account_repository.dart';
import 'package:budget_view/features/analytics/domain/forecast.dart';
import 'package:budget_view/features/analytics/domain/forecast_service.dart';
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
  final anchor = DateTime(2026, 3);

  late Directory tempDir;
  late Isar isar;
  late AccountRepository accounts;
  late TransactionRepository transactions;
  late LineItemRepository lineItems;
  late CategoryRepository categories;
  late ForecastService service;
  late Account giro;
  late Category food;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_forecast_');
    isar = await openAppIsar(directory: tempDir.path);
    final sync = LocalSyncAdapter(isar);
    accounts = AccountRepository(isar, sync);
    transactions = TransactionRepository(isar, sync);
    lineItems = LineItemRepository(isar, sync, transactions);
    categories = CategoryRepository(isar, sync, transactions);
    service = ForecastService(
      MonthlyCategoryReportService(
        transactions,
        lineItems,
        categories,
        accounts,
      ),
    );
    giro = await accounts.save(
      Account()
        ..name = 'Giro'
        ..type = AccountType.giro
        ..openingBalanceCents = 0
        ..openingDate = DateTime(2025, 1, 1),
    );
    food = await categories.save(Category()..name = 'Lebensmittel');
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<Transaction> booking({
    required int month,
    required int amountCents,
    String? categoryUuid,
    String? accountUuid,
    int year = 2026,
  }) => transactions.save(
    Transaction()
      ..accountUuid = accountUuid ?? giro.uuid
      ..amountCents = amountCents
      ..categoryUuid = categoryUuid ?? food.uuid
      ..bookingDate = DateTime(year, month, 15)
      ..description = 'REWE',
  );

  Future<ForecastResult> forecast({
    String? categoryUuid,
    int? windowMonths = 3,
    int horizonMonths = 2,
    String? accountUuid,
    ReportDirection direction = ReportDirection.expenses,
  }) => service.compute(
    categoryUuid: categoryUuid ?? food.uuid,
    anchorMonth: anchor,
    windowMonths: windowMonths,
    horizonMonths: horizonMonths,
    accountUuid: accountUuid,
    direction: direction,
  );

  test('a linear history projects the next months exactly', () async {
    await booking(month: 1, amountCents: -1000);
    await booking(month: 2, amountCents: -2000);
    await booking(month: 3, amountCents: -3000);

    final result = await forecast();

    expect(result.history.map((value) => value.cents), [1000, 2000, 3000]);
    expect(result.history.first.month, 1);
    expect(result.hasForecast, isTrue);
    expect(result.slopeCentsPerMonth, closeTo(1000, 1e-9));
    expect(result.r2, closeTo(1.0, 1e-9));
    expect(result.forecast.map((value) => value.cents), [4000, 5000]);
    expect(result.forecast.map((value) => value.month), [4, 5]);
    expect(result.forecast.last.year, 2026);
  });

  test('a month without bookings counts as zero, not as a gap', () async {
    await booking(month: 1, amountCents: -1000);
    await booking(month: 3, amountCents: -3000);

    final result = await forecast();

    expect(result.history.map((value) => value.cents), [1000, 0, 3000]);
  });

  test('the projection floors at zero instead of going negative', () async {
    await booking(month: 1, amountCents: -3000);
    await booking(month: 2, amountCents: -2000);
    await booking(month: 3, amountCents: -1000);

    final result = await forecast(horizonMonths: 3);

    expect(result.slopeCentsPerMonth, closeTo(-1000, 1e-9));
    expect(result.forecast.map((value) => value.cents), [0, 0, 0]);
  });

  test('a window shorter than three months yields no line', () async {
    await booking(month: 2, amountCents: -1000);
    await booking(month: 3, amountCents: -2000);

    final result = await forecast(windowMonths: 2);

    expect(result.hasForecast, isFalse);
    expect(result.history, hasLength(2));
    expect(result.slopeCentsPerMonth, 0);
    expect(result.r2, 0);
  });

  test('the window cuts off older months', () async {
    await booking(month: 11, amountCents: -9900, year: 2025);
    await booking(month: 1, amountCents: -1000);
    await booking(month: 2, amountCents: -2000);
    await booking(month: 3, amountCents: -3000);

    final result = await forecast();

    expect(result.history, hasLength(3));
    expect(result.history.first.month, 1);
  });

  test('a null window starts at the first month with data', () async {
    await booking(month: 12, amountCents: -500, year: 2025);
    await booking(month: 2, amountCents: -2000);
    await booking(month: 3, amountCents: -3000);

    final result = await forecast(windowMonths: null);

    expect(result.history.map((value) => value.cents), [500, 0, 2000, 3000]);
    expect(result.history.first.year, 2025);
    expect(result.history.first.month, 12);
  });

  test('months after the anchor never enter the history', () async {
    await booking(month: 1, amountCents: -1000);
    await booking(month: 2, amountCents: -2000);
    await booking(month: 3, amountCents: -3000);
    await booking(month: 4, amountCents: -9900);

    final result = await forecast();

    expect(result.history, hasLength(3));
    expect(result.history.last.month, 3);
    expect(result.history.last.cents, 3000);
  });

  test('income bookings stay out of an expense forecast', () async {
    await booking(month: 1, amountCents: -1000);
    await booking(month: 2, amountCents: -2000);
    await booking(month: 3, amountCents: -3000);
    await booking(month: 3, amountCents: 250000);

    final expenses = await forecast();
    expect(expenses.history.last.cents, 3000);

    final income = await forecast(direction: ReportDirection.income);
    expect(income.history.map((value) => value.cents), [0, 0, 250000]);
  });

  test('an account filter narrows the series', () async {
    final second = await accounts.save(
      Account()
        ..name = 'Zweitkonto'
        ..type = AccountType.giro
        ..openingBalanceCents = 0
        ..openingDate = DateTime(2025, 1, 1),
    );
    await booking(month: 3, amountCents: -1000);
    await booking(month: 3, amountCents: -7000, accountUuid: second.uuid);

    expect((await forecast()).history.last.cents, 8000);
    expect((await forecast(accountUuid: giro.uuid)).history.last.cents, 1000);
  });

  test('the series uses the rollup, so children count for the parent', () async {
    final drinks = await categories.save(
      Category()
        ..name = 'Getränke'
        ..parentUuid = food.uuid,
    );
    await booking(month: 3, amountCents: -1000);
    await booking(month: 3, amountCents: -250, categoryUuid: drinks.uuid);

    expect((await forecast()).history.last.cents, 1250);
    expect(
      (await forecast(categoryUuid: drinks.uuid)).history.last.cents,
      250,
    );
  });

  test('a position override moves the month value to its own category', () async {
    final household = await categories.save(Category()..name = 'Haushalt');
    final parent = await booking(month: 3, amountCents: -1000);
    await lineItems.save(
      LineItem()
        ..transactionUuid = parent.uuid
        ..amountCents = -400
        ..categoryUuid = household.uuid
        ..description = 'Spülmittel',
    );
    await lineItems.save(
      LineItem()
        ..transactionUuid = parent.uuid
        ..amountCents = -600
        ..description = 'Milch',
    );

    expect((await forecast()).history.last.cents, 600);
    expect(
      (await forecast(categoryUuid: household.uuid)).history.last.cents,
      400,
    );
  });

  test('a category without any history reports zeros, not a crash', () async {
    await booking(month: 1, amountCents: -1000);
    final unused = await categories.save(Category()..name = 'Ungenutzt');

    final result = await forecast(categoryUuid: unused.uuid);

    expect(result.history.map((value) => value.cents), [0, 0, 0]);
    expect(result.slopeCentsPerMonth, 0);
    expect(result.r2, 0);
    expect(result.forecast.map((value) => value.cents), [0, 0]);
  });
}
