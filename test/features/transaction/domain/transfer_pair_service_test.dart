import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/features/account/data/account.dart';
import 'package:budget_view/features/account/data/account_type.dart';
import 'package:budget_view/features/account/domain/account_repository.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/domain/transaction_repository.dart';
import 'package:budget_view/features/transaction/domain/transfer_pair_service.dart';

Account _account({
  String name = 'Giro',
  AccountType type = AccountType.giro,
}) {
  return Account()
    ..name = name
    ..type = type
    ..openingBalanceCents = 0
    ..openingDate = DateTime(2024, 1, 1);
}

Transaction _tx({
  required String accountUuid,
  int amountCents = -5000,
  DateTime? bookingDate,
  String description = 'Umbuchung',
  TransactionKind kind = TransactionKind.transfer,
}) {
  return Transaction()
    ..accountUuid = accountUuid
    ..amountCents = amountCents
    ..bookingDate = bookingDate ?? DateTime(2026, 8, 1)
    ..description = description
    ..kind = kind;
}

void main() {
  late Directory tempDir;
  late Isar isar;
  late TransactionRepository transactions;
  late AccountRepository accounts;
  late TransferPairService service;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_pair_');
    isar = await openAppIsar(directory: tempDir.path);
    transactions = TransactionRepository(isar, LocalSyncAdapter(isar));
    accounts = AccountRepository(isar, LocalSyncAdapter(isar));
    service = TransferPairService(transactions, accounts);
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('creates the counter-leg on the target account', () async {
    final giro = await accounts.save(_account(name: 'Giro'));
    final tagesgeld = await accounts.save(
      _account(name: 'Tagesgeld', type: AccountType.tagesgeld),
    );
    final source = await transactions.save(
      _tx(accountUuid: giro.uuid, amountCents: -5000),
    );

    await service.syncCounterpart(
      source,
      targetAccountUuid: tagesgeld.uuid,
    );

    final leg = (await transactions.findByAccount(tagesgeld.uuid)).single;
    expect(leg.amountCents, 5000);
    expect(leg.bookingDate, source.bookingDate);
    expect(leg.kind, TransactionKind.transfer);
    expect(leg.counterparty, 'Giro');
    expect(leg.description, 'Umbuchung von Giro');
    expect(leg.categoryUuid, isNull);
  });

  test('links both legs to each other by uuid', () async {
    final giro = await accounts.save(_account(name: 'Giro'));
    final tagesgeld = await accounts.save(
      _account(name: 'Tagesgeld', type: AccountType.tagesgeld),
    );
    final source = await transactions.save(
      _tx(accountUuid: giro.uuid, amountCents: -5000),
    );

    await service.syncCounterpart(
      source,
      targetAccountUuid: tagesgeld.uuid,
    );

    final leg = (await transactions.findByAccount(tagesgeld.uuid)).single;
    final reloadedSource = await transactions.findByUuid(source.uuid);
    final reloadedLeg = await transactions.findByUuid(leg.uuid);

    expect(reloadedSource!.counterpartUuid, reloadedLeg!.uuid);
    expect(reloadedLeg.counterpartUuid, reloadedSource.uuid);
  });

  test('a positive source amount describes arrival on the source account',
      () async {
    final giro = await accounts.save(_account(name: 'Giro'));
    final tagesgeld = await accounts.save(
      _account(name: 'Tagesgeld', type: AccountType.tagesgeld),
    );
    final source = await transactions.save(
      _tx(accountUuid: giro.uuid, amountCents: 5000),
    );

    await service.syncCounterpart(
      source,
      targetAccountUuid: tagesgeld.uuid,
    );

    final leg = (await transactions.findByAccount(tagesgeld.uuid)).single;
    expect(leg.description, 'Umbuchung nach Giro');
  });

  test('no target on a transfer writes no counter-leg', () async {
    final giro = await accounts.save(_account(name: 'Giro'));
    final source = await transactions.save(
      _tx(accountUuid: giro.uuid, amountCents: -5000),
    );

    await service.syncCounterpart(source, targetAccountUuid: null);

    final onGiro = await transactions.findByAccount(giro.uuid);
    expect(onGiro.map((t) => t.uuid), [source.uuid]);
    final reloadedSource = await transactions.findByUuid(source.uuid);
    expect(reloadedSource!.counterpartUuid, isNull);
  });

  test('a regular booking never pairs even with a target given', () async {
    final giro = await accounts.save(_account(name: 'Giro'));
    final tagesgeld = await accounts.save(
      _account(name: 'Tagesgeld', type: AccountType.tagesgeld),
    );
    final source = await transactions.save(
      _tx(
        accountUuid: giro.uuid,
        amountCents: -5000,
        kind: TransactionKind.regular,
      ),
    );

    await service.syncCounterpart(
      source,
      targetAccountUuid: tagesgeld.uuid,
    );

    expect(await transactions.findByAccount(tagesgeld.uuid), isEmpty);
  });

  test('editing the source amount mirrors onto the counter-leg', () async {
    final giro = await accounts.save(_account(name: 'Giro'));
    final tagesgeld = await accounts.save(
      _account(name: 'Tagesgeld', type: AccountType.tagesgeld),
    );
    var source = await transactions.save(
      _tx(accountUuid: giro.uuid, amountCents: -5000),
    );
    await service.syncCounterpart(source, targetAccountUuid: tagesgeld.uuid);
    final firstLeg = (await transactions.findByAccount(tagesgeld.uuid)).single;

    source.amountCents = -7500;
    source = await transactions.save(source);
    await service.syncCounterpart(source, targetAccountUuid: tagesgeld.uuid);

    final leg = (await transactions.findByAccount(tagesgeld.uuid)).single;
    expect(leg.uuid, firstLeg.uuid);
    expect(leg.amountCents, 7500);
  });

  test('editing the source date mirrors onto the counter-leg', () async {
    final giro = await accounts.save(_account(name: 'Giro'));
    final tagesgeld = await accounts.save(
      _account(name: 'Tagesgeld', type: AccountType.tagesgeld),
    );
    var source = await transactions.save(
      _tx(accountUuid: giro.uuid, amountCents: -5000),
    );
    await service.syncCounterpart(source, targetAccountUuid: tagesgeld.uuid);
    final firstLeg = (await transactions.findByAccount(tagesgeld.uuid)).single;

    final newDate = DateTime(2026, 8, 15);
    source.bookingDate = newDate;
    source = await transactions.save(source);
    await service.syncCounterpart(source, targetAccountUuid: tagesgeld.uuid);

    final leg = (await transactions.findByAccount(tagesgeld.uuid)).single;
    expect(leg.uuid, firstLeg.uuid);
    expect(leg.bookingDate, newDate);
  });

  test('a sign flip rewrites a still-generated description', () async {
    final giro = await accounts.save(_account(name: 'Giro'));
    final tagesgeld = await accounts.save(
      _account(name: 'Tagesgeld', type: AccountType.tagesgeld),
    );
    var source = await transactions.save(
      _tx(accountUuid: giro.uuid, amountCents: -5000),
    );
    await service.syncCounterpart(source, targetAccountUuid: tagesgeld.uuid);
    final beforeFlip =
        (await transactions.findByAccount(tagesgeld.uuid)).single;
    expect(beforeFlip.description, 'Umbuchung von Giro');

    source.amountCents = 5000;
    source = await transactions.save(source);
    await service.syncCounterpart(source, targetAccountUuid: tagesgeld.uuid);

    final afterFlip =
        (await transactions.findByAccount(tagesgeld.uuid)).single;
    expect(afterFlip.description, 'Umbuchung nach Giro');
  });

  test('a sign flip leaves a user-edited description untouched', () async {
    final giro = await accounts.save(_account(name: 'Giro'));
    final tagesgeld = await accounts.save(
      _account(name: 'Tagesgeld', type: AccountType.tagesgeld),
    );
    var source = await transactions.save(
      _tx(accountUuid: giro.uuid, amountCents: -5000),
    );
    await service.syncCounterpart(source, targetAccountUuid: tagesgeld.uuid);
    var leg = (await transactions.findByAccount(tagesgeld.uuid)).single;
    leg.description = 'Sparen für Urlaub';
    await transactions.save(leg);

    source.amountCents = 5000;
    source = await transactions.save(source);
    await service.syncCounterpart(source, targetAccountUuid: tagesgeld.uuid);

    leg = (await transactions.findByAccount(tagesgeld.uuid)).single;
    expect(leg.description, 'Sparen für Urlaub');
  });

  test('changing the target moves the counter-leg, keeping its uuid',
      () async {
    final giro = await accounts.save(_account(name: 'Giro'));
    final tagesgeld = await accounts.save(
      _account(name: 'Tagesgeld', type: AccountType.tagesgeld),
    );
    final sparkonto = await accounts.save(
      _account(name: 'Sparkonto', type: AccountType.sparkonto),
    );
    var source = await transactions.save(
      _tx(accountUuid: giro.uuid, amountCents: -5000),
    );
    await service.syncCounterpart(source, targetAccountUuid: tagesgeld.uuid);
    final firstLeg = (await transactions.findByAccount(tagesgeld.uuid)).single;

    source = (await transactions.findByUuid(source.uuid))!;
    await service.syncCounterpart(source, targetAccountUuid: sparkonto.uuid);

    final movedLeg =
        (await transactions.findByAccount(sparkonto.uuid)).single;
    expect(movedLeg.uuid, firstLeg.uuid);
    expect(movedLeg.accountUuid, sparkonto.uuid);
    expect(await transactions.findByAccount(tagesgeld.uuid), isEmpty);
  });

  test('clearing the target soft-deletes the leg and drops the link',
      () async {
    final giro = await accounts.save(_account(name: 'Giro'));
    final tagesgeld = await accounts.save(
      _account(name: 'Tagesgeld', type: AccountType.tagesgeld),
    );
    var source = await transactions.save(
      _tx(accountUuid: giro.uuid, amountCents: -5000),
    );
    await service.syncCounterpart(source, targetAccountUuid: tagesgeld.uuid);
    final firstLeg = (await transactions.findByAccount(tagesgeld.uuid)).single;

    source = (await transactions.findByUuid(source.uuid))!;
    await service.syncCounterpart(source, targetAccountUuid: null);

    // `softDelete` flips a flag and keeps the row, and `findByUuid` reads it
    // raw — so the row is still findable, just marked.
    expect((await transactions.findByUuid(firstLeg.uuid))!.deleted, isTrue);
    // What the target account lists is empty again, which is the visible half.
    expect(await transactions.findByAccount(tagesgeld.uuid), isEmpty);
    final reloadedSource = await transactions.findByUuid(source.uuid);
    expect(reloadedSource!.counterpartUuid, isNull);
  });

  test('deletePair takes both legs down', () async {
    final giro = await accounts.save(_account(name: 'Giro'));
    final tagesgeld = await accounts.save(
      _account(name: 'Tagesgeld', type: AccountType.tagesgeld),
    );
    var source = await transactions.save(
      _tx(accountUuid: giro.uuid, amountCents: -5000),
    );
    await service.syncCounterpart(source, targetAccountUuid: tagesgeld.uuid);
    source = (await transactions.findByUuid(source.uuid))!;
    final leg = (await transactions.findByAccount(tagesgeld.uuid)).single;

    await service.deletePair(source);

    expect((await transactions.findByUuid(source.uuid))!.deleted, isTrue);
    expect((await transactions.findByUuid(leg.uuid))!.deleted, isTrue);
    // Neither account lists a booking any more: no half transfer is left.
    expect(await transactions.findByAccount(giro.uuid), isEmpty);
    expect(await transactions.findByAccount(tagesgeld.uuid), isEmpty);
  });

  test('deletePair on an unpaired booking deletes only that one', () async {
    final giro = await accounts.save(_account(name: 'Giro'));
    final lone = await transactions.save(
      _tx(
        accountUuid: giro.uuid,
        amountCents: -5000,
        kind: TransactionKind.regular,
      ),
    );

    await service.deletePair(lone);

    expect((await transactions.findByUuid(lone.uuid))!.deleted, isTrue);
    expect(await transactions.findByAccount(giro.uuid), isEmpty);
  });

  test('counterpartAccountOf returns the other account', () async {
    final giro = await accounts.save(_account(name: 'Giro'));
    final tagesgeld = await accounts.save(
      _account(name: 'Tagesgeld', type: AccountType.tagesgeld),
    );
    var source = await transactions.save(
      _tx(accountUuid: giro.uuid, amountCents: -5000),
    );
    await service.syncCounterpart(source, targetAccountUuid: tagesgeld.uuid);
    source = (await transactions.findByUuid(source.uuid))!;

    final other = await service.counterpartAccountOf(source);

    expect(other!.uuid, tagesgeld.uuid);
  });

  test('counterpartAccountOf returns null for an unpaired booking',
      () async {
    final giro = await accounts.save(_account(name: 'Giro'));
    final lone = await transactions.save(
      _tx(
        accountUuid: giro.uuid,
        amountCents: -5000,
        kind: TransactionKind.regular,
      ),
    );

    final other = await service.counterpartAccountOf(lone);

    expect(other, isNull);
  });

  test(
    'equal amounts on two accounts stay unpaired without a named target',
    () async {
      final giro = await accounts.save(_account(name: 'Giro'));
      final tagesgeld = await accounts.save(
        _account(name: 'Tagesgeld', type: AccountType.tagesgeld),
      );
      final day = DateTime(2026, 8, 1);
      final a = await transactions.save(
        _tx(accountUuid: giro.uuid, amountCents: -5000, bookingDate: day),
      );
      final b = await transactions.save(
        _tx(accountUuid: tagesgeld.uuid, amountCents: 5000, bookingDate: day),
      );

      final reloadedA = await transactions.findByUuid(a.uuid);
      final reloadedB = await transactions.findByUuid(b.uuid);

      expect(reloadedA!.counterpartUuid, isNull);
      expect(reloadedB!.counterpartUuid, isNull);
    },
  );
}
