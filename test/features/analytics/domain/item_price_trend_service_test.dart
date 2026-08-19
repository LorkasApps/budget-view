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
    tempDir = await Directory.systemTemp.createTemp('budgetview_itemtrend_');
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

  Future<Transaction> booking({
    String? accountUuid,
    int amountCents = -500,
    DateTime? bookingDate,
    String description = 'Bon',
  }) => transactions.save(
    Transaction()
      ..accountUuid = accountUuid ?? giro.uuid
      ..amountCents = amountCents
      ..bookingDate = bookingDate ?? DateTime(2026, 1, 1)
      ..description = description,
  );

  Future<LineItem> position({
    required String transactionUuid,
    required int amountCents,
    required String description,
    double? quantity,
    int? unitPriceCents,
  }) => lineItems.save(
    LineItem()
      ..transactionUuid = transactionUuid
      ..amountCents = amountCents
      ..description = description
      ..quantity = quantity
      ..unitPriceCents = unitPriceCents,
  );

  Future<LineItem> restposten({
    required String transactionUuid,
    required int amountCents,
    String description = 'Restposten',
  }) => lineItems.saveRestposten(
    LineItem()
      ..transactionUuid = transactionUuid
      ..amountCents = amountCents
      ..kind = LineItemKind.restposten
      ..description = description,
  );

  test(
    'casing and whitespace variants land in one group, a different '
    'flavour does not',
    () async {
      final b1 = await booking(bookingDate: DateTime(2026, 1, 1));
      final b2 = await booking(bookingDate: DateTime(2026, 1, 2));
      final b3 = await booking(bookingDate: DateTime(2026, 1, 3));
      final other = await booking(bookingDate: DateTime(2026, 1, 4));
      await position(
        transactionUuid: b1.uuid,
        amountCents: -159,
        description: 'H-Milch 1,5%',
      );
      await position(
        transactionUuid: b2.uuid,
        amountCents: -159,
        description: 'h-milch 1,5%',
      );
      await position(
        transactionUuid: b3.uuid,
        amountCents: -159,
        description: 'h-milch  1,5%',
      );
      await position(
        transactionUuid: other.uuid,
        amountCents: -179,
        description: 'h-milch 3,5%',
      );

      final fatFree = await service.series('h-milch 1,5%');
      final fullFat = await service.series('h-milch 3,5%');

      expect(fatFree.count, 3);
      expect(fullFat.count, 1);
    },
  );

  test('a printed unit price wins over quantity and amount', () async {
    final b = await booking();
    await position(
      transactionUuid: b.uuid,
      amountCents: -500,
      description: 'Apfel',
      quantity: 3,
      unitPriceCents: 199,
    );

    final series = await service.series('apfel');

    expect(series.points.single.unitPriceCents, 199);
  });

  test(
    'without a printed price, quantity derives the unit price by rounding',
    () async {
      final b = await booking();
      await position(
        transactionUuid: b.uuid,
        amountCents: -1000,
        description: 'Birne',
        quantity: 3,
      );

      final series = await service.series('birne');

      expect(series.points.single.unitPriceCents, 333);
    },
  );

  test(
    'without a printed price or quantity, the amount is the unit price',
    () async {
      final b = await booking();
      await position(
        transactionUuid: b.uuid,
        amountCents: -750,
        description: 'Brot',
      );

      final series = await service.series('brot');

      expect(series.points.single.unitPriceCents, 750);
    },
  );

  test('a restposten row contributes nothing to any group', () async {
    final b = await booking(amountCents: -1055);
    await position(
      transactionUuid: b.uuid,
      amountCents: -1000,
      description: 'Kaese',
    );
    await restposten(transactionUuid: b.uuid, amountCents: -55);

    expect((await service.series('kaese')).count, 1);
    expect((await service.series('restposten')).isEmpty, isTrue);
  });

  test('each point uses the parent booking date, oldest first', () async {
    final b1 = await booking(bookingDate: DateTime(2026, 3, 1));
    final b2 = await booking(bookingDate: DateTime(2026, 1, 1));
    final b3 = await booking(bookingDate: DateTime(2026, 2, 1));
    await position(
      transactionUuid: b1.uuid,
      amountCents: -100,
      description: 'Ei',
    );
    await position(
      transactionUuid: b2.uuid,
      amountCents: -200,
      description: 'Ei',
    );
    await position(
      transactionUuid: b3.uuid,
      amountCents: -300,
      description: 'Ei',
    );

    final series = await service.series('ei');

    expect(series.points.map((p) => p.date), [
      DateTime(2026, 1, 1),
      DateTime(2026, 2, 1),
      DateTime(2026, 3, 1),
    ]);
    expect(series.points.map((p) => p.unitPriceCents), [200, 300, 100]);
  });

  test('the label follows the most recent purchase, trimmed', () async {
    final older = await booking(bookingDate: DateTime(2026, 1, 1));
    final newer = await booking(bookingDate: DateTime(2026, 2, 1));
    await position(
      transactionUuid: older.uuid,
      amountCents: -100,
      description: 'cola',
    );
    await position(
      transactionUuid: newer.uuid,
      amountCents: -100,
      description: '  Cola  ',
    );

    final series = await service.series('cola');

    expect(series.label, 'Cola');
  });

  test('an unknown key returns an empty series named after the key', () async {
    final series = await service.series('Does Not Exist');

    expect(series.isEmpty, isTrue);
    expect(series.count, 0);
    expect(series.minUnitPriceCents, isNull);
    expect(series.maxUnitPriceCents, isNull);
    expect(series.label, 'does not exist');
    expect(series.normalizedKey, 'does not exist');
  });

  test("an archived account's positions drop out of the series", () async {
    final second = await accounts.save(
      Account()
        ..name = 'Zweitkonto'
        ..type = AccountType.giro
        ..openingBalanceCents = 0
        ..openingDate = DateTime(2025, 1, 1),
    );
    final b = await booking(accountUuid: second.uuid);
    await position(
      transactionUuid: b.uuid,
      amountCents: -100,
      description: 'Wurst',
    );
    await accounts.softDelete(second.uuid);

    expect((await service.series('wurst')).isEmpty, isTrue);
  });

  test('positions of a soft-deleted booking drop out of the series', () async {
    final b = await booking();
    await position(
      transactionUuid: b.uuid,
      amountCents: -100,
      description: 'Senf',
    );
    await transactions.softDelete(b.uuid);

    expect((await service.series('senf')).isEmpty, isTrue);
  });

  test('a soft-deleted position drops out of the series', () async {
    final b = await booking();
    await position(
      transactionUuid: b.uuid,
      amountCents: -100,
      description: 'Zwiebel',
    );
    final dropped = await position(
      transactionUuid: b.uuid,
      amountCents: -200,
      description: 'Zwiebel',
    );
    await lineItems.softDelete(dropped.uuid);

    final series = await service.series('zwiebel');

    expect(series.count, 1);
    expect(series.points.single.unitPriceCents, 100);
  });
}
