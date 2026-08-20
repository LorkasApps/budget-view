import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_repository.dart';
import 'package:budget_view/features/tagging/domain/tagging_rule_repository.dart';
import 'package:budget_view/features/transaction/domain/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

/// Archiving a category must not take its learned rules with it: the rule
/// survives and turns stale, which is what ticket 025's screen then offers to
/// remap or delete.
void main() {
  late Directory tempDir;
  late Isar isar;
  late CategoryRepository categories;
  late TaggingRuleRepository rules;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_rule_archive_');
    isar = await openAppIsar(directory: tempDir.path);
    final sync = LocalSyncAdapter(isar);
    categories = CategoryRepository(isar, sync, TransactionRepository(isar, sync));
    rules = TaggingRuleRepository(isar, sync);
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('archiving a category keeps the rules pointing at it', () async {
    final category = await categories.save(Category()..name = 'Freizeit');
    final rule = await rules.upsert('zoo fachhandel', category.uuid);

    await categories.delete(category.uuid);

    final survivor = await rules.findByUuid(rule.uuid);
    expect(survivor, isNotNull);
    expect(survivor!.categoryUuid, category.uuid);
    expect(survivor.hitCount, 1);

    final archived = await categories.findByUuid(category.uuid);
    expect(archived?.archived, isTrue);
  });
}
