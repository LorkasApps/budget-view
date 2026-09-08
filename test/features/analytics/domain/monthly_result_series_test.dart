import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/features/account/data/account.dart';
import 'package:budget_view/features/account/data/account_type.dart';
import 'package:budget_view/features/account/domain/account_repository.dart';
import 'package:budget_view/features/analytics/domain/monthly_category_report_service.dart';
import 'package:budget_view/features/analytics/domain/result_series.dart';
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
    tempDir = await Directory.systemTemp.createTemp('budgetview_result_');
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

  Future<Transaction> booking({
    required String accountUuid,
    required int amountCents,
    DateTime? bookingDate,
    String description = 'REWE',
    TransactionKind kind = TransactionKind.regular,
  }) => transactions.save(
    Transaction()
      ..accountUuid = accountUuid
      ..amountCents = amountCents
      ..bookingDate = bookingDate ?? DateTime(2026, 8, 12)
      ..description = description
      ..kind = kind,
  );

  /// Goes through [ResultFilter] on purpose, so the mapping of a mode onto
  /// anchor and window is covered by the same tests as the arithmetic.
  Future<ResultSeries> result(ResultFilter filter) =>
      service.computeResultSeries(
        anchorMonth: filter.anchorMonth,
        windowMonths: filter.windowMonths,
        accountUuid: filter.accountUuid,
      );

  test('the result is income minus expenses', () async {
    final giro = await account();
    await booking(accountUuid: giro.uuid, amountCents: 250000);
    await booking(accountUuid: giro.uuid, amountCents: -95000);
    await booking(accountUuid: giro.uuid, amountCents: -4732);

    final series = await result(const ResultFilter(year: 2026, month: 8));

    expect(series.points, hasLength(1));
    expect(series.incomeCents, 250000);
    expect(series.expenseCents, 99732);
    expect(series.netCents, 150268);
  });

  test('a negative month keeps its sign', () async {
    final giro = await account();
    await booking(accountUuid: giro.uuid, amountCents: 100000);
    await booking(accountUuid: giro.uuid, amountCents: -109307);

    final series = await result(const ResultFilter(year: 2026, month: 8));

    expect(series.netCents, -9307);
  });

  test('a transfer counts in none of the three figures', () async {
    final giro = await account();
    final savings = await account(name: 'Extra');
    await booking(accountUuid: giro.uuid, amountCents: 250000);
    await booking(accountUuid: giro.uuid, amountCents: -95000);
    await booking(
      accountUuid: giro.uuid,
      amountCents: -50000,
      kind: TransactionKind.transfer,
      description: 'Umbuchung',
    );
    await booking(
      accountUuid: savings.uuid,
      amountCents: 50000,
      kind: TransactionKind.transfer,
      description: 'Umbuchung',
    );

    final series = await result(const ResultFilter(year: 2026, month: 8));

    expect(series.incomeCents, 250000);
    expect(series.expenseCents, 95000);
    expect(series.netCents, 155000);
  });

  test('positions replace their booking instead of doubling it', () async {
    final giro = await account();
    final groceries = await booking(
      accountUuid: giro.uuid,
      amountCents: -5000,
    );
    await lineItems.save(
      LineItem()
        ..transactionUuid = groceries.uuid
        ..amountCents = -3000
        ..description = 'Käse',
    );
    await lineItems.save(
      LineItem()
        ..transactionUuid = groceries.uuid
        ..amountCents = -2000
        ..description = 'Brot',
    );

    final series = await result(const ResultFilter(year: 2026, month: 8));

    expect(series.expenseCents, 5000);
  });

  test('a month without bookings is three zeros', () async {
    await account();

    final series = await result(const ResultFilter(year: 2026, month: 3));

    expect(series.points, hasLength(1));
    expect(series.incomeCents, 0);
    expect(series.expenseCents, 0);
    expect(series.netCents, 0);
  });

  test('a year is twelve months, oldest first', () async {
    final giro = await account();
    await booking(
      accountUuid: giro.uuid,
      amountCents: 500000,
      bookingDate: DateTime(2026, 2, 3),
    );
    await booking(
      accountUuid: giro.uuid,
      amountCents: -120000,
      bookingDate: DateTime(2026, 11, 28),
    );

    final series = await result(const ResultFilter(year: 2026));

    expect(series.points, hasLength(12));
    expect(series.points.first.month, 1);
    expect(series.points.last.month, 12);
    expect(series.points[0].netCents, 0);
    expect(series.points[1].incomeCents, 500000);
    expect(series.points[10].expenseCents, 120000);
  });

  test('the year figures are the sum of its twelve rows', () async {
    final giro = await account();
    await booking(
      accountUuid: giro.uuid,
      amountCents: 500000,
      bookingDate: DateTime(2026, 2, 3),
    );
    await booking(
      accountUuid: giro.uuid,
      amountCents: 250000,
      bookingDate: DateTime(2026, 7, 1),
    );
    await booking(
      accountUuid: giro.uuid,
      amountCents: -120000,
      bookingDate: DateTime(2026, 11, 28),
    );

    final series = await result(const ResultFilter(year: 2026));

    final income = series.points.fold(0, (sum, p) => sum + p.incomeCents);
    final expenses = series.points.fold(0, (sum, p) => sum + p.expenseCents);
    expect(series.incomeCents, income);
    expect(series.expenseCents, expenses);
    expect(series.netCents, income - expenses);
    expect(series.netCents, 630000);
  });

  test('an empty year is twelve zero rows, not an empty series', () async {
    await account();

    final series = await result(const ResultFilter(year: 2026));

    expect(series.points, hasLength(12));
    expect(series.netCents, 0);
  });

  test('a month equals its own row inside the year', () async {
    final giro = await account();
    await booking(
      accountUuid: giro.uuid,
      amountCents: 500000,
      bookingDate: DateTime(2026, 2, 3),
    );
    await booking(
      accountUuid: giro.uuid,
      amountCents: -47320,
      bookingDate: DateTime(2026, 2, 20),
    );

    final february = await result(const ResultFilter(year: 2026, month: 2));
    final year = await result(const ResultFilter(year: 2026));

    expect(february.incomeCents, year.points[1].incomeCents);
    expect(february.expenseCents, year.points[1].expenseCents);
    expect(february.netCents, year.points[1].netCents);
  });

  test('the account filter decides which bookings count', () async {
    final giro = await account();
    final extra = await account(name: 'Extra');
    await booking(accountUuid: giro.uuid, amountCents: -95000);
    await booking(accountUuid: extra.uuid, amountCents: -1000);

    final all = await result(const ResultFilter(year: 2026, month: 8));
    final giroOnly = await result(
      ResultFilter(year: 2026, month: 8, accountUuid: giro.uuid),
    );

    expect(all.expenseCents, 96000);
    expect(giroOnly.expenseCents, 95000);
  });
}
