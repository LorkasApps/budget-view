import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/features/tagging/data/tagging_rule.dart';
import 'package:budget_view/features/tagging/domain/tagging_rule_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late TaggingRuleRepository repo;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_tagging_');
    isar = await openAppIsar(directory: tempDir.path);
    repo = TaggingRuleRepository(isar, LocalSyncAdapter(isar));
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'the first upsert creates a rule with hitCount 1, a uuid and timestamps',
    () async {
      final rule = await repo.upsert('rewe berlin', 'cat-groceries');

      expect(rule.hitCount, 1);
      expect(rule.uuid, isNotEmpty);
      expect(rule.matchValueNorm, 'rewe berlin');
      expect(rule.categoryUuid, 'cat-groceries');
      expect(rule.matchField, TaggingMatchField.counterparty);
      expect(rule.createdAt, isNotNull);
      expect(rule.updatedAt, isNotNull);
      expect(rule.lastAssignedAt, isNotNull);
    },
  );

  test(
    'a second upsert of the same triple increments the count instead of '
    'inserting a second row',
    () async {
      final first = await repo.upsert('rewe berlin', 'cat-groceries');
      final second = await repo.upsert('rewe berlin', 'cat-groceries');

      expect(second.hitCount, 2);
      expect(second.uuid, first.uuid);
      expect(await repo.findAll(), hasLength(1));
    },
  );

  test(
    'the same counterparty assigned to a different category yields a '
    'second, independent rule',
    () async {
      final groceries = await repo.upsert('rewe berlin', 'cat-groceries');
      final drugstore = await repo.upsert('rewe berlin', 'cat-drugstore');
      await repo.upsert('rewe berlin', 'cat-groceries');

      final all = await repo.findAll();
      expect(all, hasLength(2));

      final refreshedGroceries = all.firstWhere(
        (rule) => rule.uuid == groceries.uuid,
      );
      final refreshedDrugstore = all.firstWhere(
        (rule) => rule.uuid == drugstore.uuid,
      );
      expect(refreshedGroceries.hitCount, 2);
      expect(refreshedDrugstore.hitCount, 1);
    },
  );

  test(
    'findByCounterparty returns the strongest rule first and ignores a '
    'different counterparty',
    () async {
      await repo.upsert('rewe berlin', 'cat-drugstore');
      await repo.upsert('rewe berlin', 'cat-groceries');
      await repo.upsert('rewe berlin', 'cat-groceries');
      await repo.upsert('aldi hamburg', 'cat-groceries');

      final matches = await repo.findByCounterparty('rewe berlin');

      expect(matches.map((rule) => rule.categoryUuid).toList(), [
        'cat-groceries',
        'cat-drugstore',
      ]);
    },
  );

  test(
    'findByCounterparty ignores rules whose matchField is description',
    () async {
      await repo.upsert('rewe berlin', 'cat-groceries');
      await repo.upsert(
        'rewe berlin',
        'cat-description-match',
        matchField: TaggingMatchField.description,
      );

      final matches = await repo.findByCounterparty('rewe berlin');

      expect(matches, hasLength(1));
      expect(matches.single.categoryUuid, 'cat-groceries');
    },
  );

  test('delete removes the row for real', () async {
    final rule = await repo.upsert('rewe berlin', 'cat-groceries');

    await repo.delete(rule.uuid);

    expect(await repo.findByUuid(rule.uuid), isNull);
  });

  test('remap changes the category but keeps hitCount', () async {
    final rule = await repo.upsert('rewe berlin', 'cat-groceries');
    await repo.upsert('rewe berlin', 'cat-groceries');

    await repo.remap(rule.uuid, 'cat-drugstore');

    final remapped = await repo.findByUuid(rule.uuid);
    expect(remapped!.categoryUuid, 'cat-drugstore');
    expect(remapped.hitCount, 2);
  });

  test('lastAssignedAt moves forward on an increment', () async {
    final first = await repo.upsert('rewe berlin', 'cat-groceries');
    final firstAssignedAt = first.lastAssignedAt;

    final second = await repo.upsert('rewe berlin', 'cat-groceries');

    final movedForward =
        second.lastAssignedAt.isAtSameMomentAs(firstAssignedAt) ||
            second.lastAssignedAt.isAfter(firstAssignedAt);
    expect(movedForward, isTrue);
  });
}
