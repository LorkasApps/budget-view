import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/features/account/data/account.dart';
import 'package:budget_view/features/account/data/account_type.dart';
import 'package:budget_view/features/account/domain/account_repository.dart';
import 'package:budget_view/features/analytics/domain/item_price_trend_service.dart';
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
  late ItemPriceTrendService service;
  late Account giro;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_itemsrch_');
    isar = await openAppIsar(directory: tempDir.path);
    final sync = LocalSyncAdapter(isar);
    accounts = AccountRepository(isar, sync);
    transactions = TransactionRepository(isar, sync);
    lineItems = LineItemRepository(isar, sync, transactions);
    service = ItemPriceTrendService(transactions, lineItems, accounts);
    giro = await accounts.save(
      Account()
        ..name = 'Giro'
        ..type = AccountType.giro
        ..openingBalanceCents = 0
        ..openingDate = DateTime(2025, 1, 1),
    );
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<Transaction> booking({DateTime? bookingDate}) => transactions.save(
    Transaction()
      ..accountUuid = giro.uuid
      ..amountCents = -500
      ..bookingDate = bookingDate ?? DateTime(2026, 1, 1)
      ..description = 'Bon',
  );

  Future<LineItem> position({
    required String transactionUuid,
    required int amountCents,
    required String description,
  }) => lineItems.save(
    LineItem()
      ..transactionUuid = transactionUuid
      ..amountCents = amountCents
      ..description = description,
  );

  test('a blank query returns nothing even when items exist', () async {
    final b = await booking();
    await position(
      transactionUuid: b.uuid,
      amountCents: -100,
      description: 'Apfel',
    );

    expect(await service.searchGroups(''), isEmpty);
    expect(await service.searchGroups('   '), isEmpty);
  });

  test('the query matches any key that contains the search text', () async {
    final b1 = await booking();
    final b2 = await booking();
    await position(
      transactionUuid: b1.uuid,
      amountCents: -100,
      description: 'Apfelsaft',
    );
    await position(
      transactionUuid: b2.uuid,
      amountCents: -100,
      description: 'Birne',
    );

    final result = await service.searchGroups('apfel');

    expect(result, hasLength(1));
    expect(result.single.normalizedKey, 'apfelsaft');
  });

  test('results sort by purchase count, ties broken by label', () async {
    final a1 = await booking(bookingDate: DateTime(2026, 1, 1));
    final a2 = await booking(bookingDate: DateTime(2026, 1, 2));
    await position(
      transactionUuid: a1.uuid,
      amountCents: -100,
      description: 'Apfel',
    );
    await position(
      transactionUuid: a2.uuid,
      amountCents: -120,
      description: 'Apfel',
    );
    final s1 = await booking(bookingDate: DateTime(2026, 1, 3));
    final s2 = await booking(bookingDate: DateTime(2026, 1, 4));
    await position(
      transactionUuid: s1.uuid,
      amountCents: -200,
      description: 'Apfelsaft',
    );
    await position(
      transactionUuid: s2.uuid,
      amountCents: -210,
      description: 'Apfelsaft',
    );
    final m1 = await booking(bookingDate: DateTime(2026, 1, 5));
    final m2 = await booking(bookingDate: DateTime(2026, 1, 6));
    final m3 = await booking(bookingDate: DateTime(2026, 1, 7));
    await position(
      transactionUuid: m1.uuid,
      amountCents: -50,
      description: 'Apfelmus',
    );
    await position(
      transactionUuid: m2.uuid,
      amountCents: -55,
      description: 'Apfelmus',
    );
    await position(
      transactionUuid: m3.uuid,
      amountCents: -60,
      description: 'Apfelmus',
    );

    final result = await service.searchGroups('apfel');

    expect(result.map((g) => g.label), ['Apfelmus', 'Apfel', 'Apfelsaft']);
    expect(result.map((g) => g.purchaseCount), [3, 2, 2]);
  });

  test(
    'latestUnitPriceCents and latestDate reflect the newest purchase',
    () async {
      final older = await booking(bookingDate: DateTime(2026, 1, 1));
      final newer = await booking(bookingDate: DateTime(2026, 3, 1));
      await position(
        transactionUuid: older.uuid,
        amountCents: -100,
        description: 'Kaffee',
      );
      await position(
        transactionUuid: newer.uuid,
        amountCents: -599,
        description: 'Kaffee',
      );

      final result = await service.searchGroups('kaffee');

      expect(result.single.latestUnitPriceCents, 599);
      expect(result.single.latestDate, DateTime(2026, 3, 1));
      expect(result.single.purchaseCount, 2);
    },
  );

  test('a query matching nothing returns an empty list', () async {
    final b = await booking();
    await position(
      transactionUuid: b.uuid,
      amountCents: -100,
      description: 'Apfel',
    );

    expect(await service.searchGroups('banane'), isEmpty);
  });
}
