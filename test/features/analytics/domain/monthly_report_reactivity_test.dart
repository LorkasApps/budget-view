import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/persistence/isar_provider.dart';
import 'package:budget_view/features/account/data/account.dart';
import 'package:budget_view/features/account/data/account_type.dart';
import 'package:budget_view/features/account/domain/account_providers.dart';
import 'package:budget_view/features/analytics/domain/analytics_providers.dart';
import 'package:budget_view/features/analytics/domain/monthly_category_report.dart';
import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_providers.dart';
import 'package:budget_view/features/drilldown/data/line_item.dart';
import 'package:budget_view/features/drilldown/domain/line_item_providers.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/domain/transaction_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

/// Covers the provider wiring rather than the arithmetic: a write to any of the
/// four collections a report reads must push a new value. Runs as a plain
/// `test()` — Isar never completes inside `testWidgets`' fake-async zone.
void main() {
  const filter = MonthlyReportFilter(year: 2026, month: 8);

  late Directory tempDir;
  late Isar isar;
  late ProviderContainer container;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_reactivity_');
    isar = await openAppIsar(directory: tempDir.path);
    container = ProviderContainer(
      overrides: [isarProvider.overrideWithValue(isar)],
    );
    container.listen(
      monthlyCategoryReportProvider(filter),
      (_, _) {},
      fireImmediately: true,
    );
  });

  tearDown(() async {
    container.dispose();
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<MonthlyCategoryReport> reportWhere(
    bool Function(MonthlyCategoryReport report) predicate,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      final value = container
          .read(monthlyCategoryReportProvider(filter))
          .valueOrNull;
      if (value != null && predicate(value)) return value;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('report never satisfied the predicate');
  }

  Future<Account> account() =>
      container.read(accountRepositoryProvider).save(
        Account()
          ..name = 'Giro'
          ..type = AccountType.giro
          ..openingBalanceCents = 0
          ..openingDate = DateTime(2026, 1, 1),
      );

  test('a new booking pushes a fresh report', () async {
    final giro = await account();
    final food = await container.read(categoryRepositoryProvider).save(
      Category()..name = 'Lebensmittel',
    );
    await reportWhere((report) => report.isEmpty);

    await container.read(transactionRepositoryProvider).save(
      Transaction()
        ..accountUuid = giro.uuid
        ..amountCents = -1000
        ..categoryUuid = food.uuid
        ..bookingDate = DateTime(2026, 8, 12)
        ..description = 'REWE',
    );

    final updated = await reportWhere((report) => report.totalCents == 1000);
    expect(updated.rowFor(food.uuid)!.rollupCents, 1000);
  });

  test('a new position pushes a fresh report', () async {
    final giro = await account();
    final food = await container.read(categoryRepositoryProvider).save(
      Category()..name = 'Lebensmittel',
    );
    final drinks = await container.read(categoryRepositoryProvider).save(
      Category()..name = 'Getränke',
    );
    final booking = await container.read(transactionRepositoryProvider).save(
      Transaction()
        ..accountUuid = giro.uuid
        ..amountCents = -1000
        ..categoryUuid = food.uuid
        ..bookingDate = DateTime(2026, 8, 12)
        ..description = 'REWE',
    );
    await reportWhere((report) => report.rowFor(food.uuid) != null);

    await container.read(lineItemRepositoryProvider).save(
      LineItem()
        ..transactionUuid = booking.uuid
        ..amountCents = -400
        ..categoryUuid = drinks.uuid
        ..description = 'Cola',
    );

    final updated = await reportWhere(
      (report) => report.rowFor(drinks.uuid) != null,
    );
    expect(updated.rowFor(drinks.uuid)!.ownCents, 400);
  });
}
