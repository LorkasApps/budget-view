import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/features/tagging/domain/tagging_learn_service.dart';
import 'package:budget_view/features/tagging/domain/tagging_rule_repository.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

// Bare, unsaved Transaction: TaggingLearnService only reads categoryUuid,
// categoryAutoSuggested, counterparty and kind, so nothing else needs a value.
Transaction _booking({
  String? categoryUuid = 'cat-groceries',
  String counterparty = 'REWE Berlin',
  bool categoryAutoSuggested = false,
  TransactionKind kind = TransactionKind.regular,
}) {
  return Transaction()
    ..categoryUuid = categoryUuid
    ..counterparty = counterparty
    ..categoryAutoSuggested = categoryAutoSuggested
    ..kind = kind;
}

void main() {
  late Directory tempDir;
  late Isar isar;
  late TaggingRuleRepository rules;
  late TaggingLearnService service;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_taglearn_');
    isar = await openAppIsar(directory: tempDir.path);
    rules = TaggingRuleRepository(isar, LocalSyncAdapter(isar));
    service = TaggingLearnService(rules);
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'a user-driven assignment with a non-empty counterparty creates a rule '
    'whose matchValueNorm is the normalized counterparty',
    () async {
      await service.learnFrom(_booking(counterparty: '  REWE   Berlin '));

      final matches = await rules.findByCounterparty('rewe berlin');
      expect(matches, hasLength(1));
      expect(matches.single.matchValueNorm, 'rewe berlin');
      expect(matches.single.categoryUuid, 'cat-groceries');
      expect(matches.single.hitCount, 1);
    },
  );

  test('a transaction with a null categoryUuid teaches nothing', () async {
    await service.learnFrom(_booking(categoryUuid: null));

    expect(await rules.findAll(), isEmpty);
  });

  test('a transaction with an empty counterparty teaches nothing', () async {
    await service.learnFrom(_booking(counterparty: ''));

    expect(await rules.findAll(), isEmpty);
  });

  test(
    'a transaction with a whitespace-only counterparty teaches nothing',
    () async {
      await service.learnFrom(_booking(counterparty: '   '));

      expect(await rules.findAll(), isEmpty);
    },
  );

  test('an accepted auto-suggestion teaches nothing', () async {
    await service.learnFrom(_booking(categoryAutoSuggested: true));

    expect(await rules.findAll(), isEmpty);
  });

  test(
    'learning twice from the same counterparty raises hitCount to 2',
    () async {
      await service.learnFrom(_booking());
      await service.learnFrom(_booking());

      final matches = await rules.findByCounterparty('rewe berlin');
      expect(matches, hasLength(1));
      expect(matches.single.hitCount, 2);
    },
  );

  test(
    'two different counterparties produce two independent rules',
    () async {
      await service.learnFrom(_booking(counterparty: 'REWE Berlin'));
      await service.learnFrom(_booking(counterparty: 'Aldi Hamburg'));

      expect(await rules.findAll(), hasLength(2));
    },
  );

  test('a transfer teaches nothing', () async {
    await service.learnFrom(_booking(kind: TransactionKind.transfer));

    expect(await rules.findAll(), isEmpty);
  });

  test('the same booking as regular teaches a rule', () async {
    await service.learnFrom(_booking(kind: TransactionKind.regular));

    expect(await rules.findAll(), hasLength(1));
  });

  test("a transfer does not raise an existing rule's hitCount", () async {
    await service.learnFrom(_booking());
    await service.learnFrom(_booking(kind: TransactionKind.transfer));

    final matches = await rules.findByCounterparty('rewe berlin');
    expect(matches, hasLength(1));
    expect(matches.single.hitCount, 1);
  });
}
