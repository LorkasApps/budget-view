import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_repository.dart';
import 'package:budget_view/features/tagging/domain/tagging_rule_repository.dart';
import 'package:budget_view/features/tagging/domain/tagging_suggest_service.dart';
import 'package:budget_view/features/transaction/domain/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late CategoryRepository categories;
  late TaggingRuleRepository rules;
  late LocalTaggingSuggestService service;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_suggest_');
    isar = await openAppIsar(directory: tempDir.path);
    final sync = LocalSyncAdapter(isar);
    final transactions = TransactionRepository(isar, sync);
    categories = CategoryRepository(isar, sync, transactions);
    rules = TaggingRuleRepository(isar, sync);
    service = LocalTaggingSuggestService(rules, categories);
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<Category> saveCategory(String name) =>
      categories.save(Category()..name = name);

  test('the strongest rule for a counterparty comes first', () async {
    final groceries = await saveCategory('Einkauf');
    final leisure = await saveCategory('Freizeit');
    await rules.upsert('rewe berlin', leisure.uuid);
    await rules.upsert('rewe berlin', groceries.uuid);
    await rules.upsert('rewe berlin', groceries.uuid);

    final suggestions = await service.suggest('REWE Berlin');

    expect(suggestions, hasLength(2));
    expect(suggestions.first.categoryUuid, groceries.uuid);
    expect(suggestions.first.hitCount, 2);
    expect(suggestions.last.categoryUuid, leisure.uuid);
    expect(suggestions.last.hitCount, 1);
  });

  test('a blank counterparty returns no suggestions', () async {
    final category = await saveCategory('Einkauf');
    await rules.upsert('rewe berlin', category.uuid);

    expect(await service.suggest(''), isEmpty);
    expect(await service.suggest('   '), isEmpty);
  });

  test(
    'a counterparty with no learned rule returns no suggestions',
    () async {
      final category = await saveCategory('Einkauf');
      await rules.upsert('rewe berlin', category.uuid);

      expect(await service.suggest('Aldi Hamburg'), isEmpty);
    },
  );

  test(
    'a rule learned from one spelling matches a differently cased and '
    'spaced query',
    () async {
      final category = await saveCategory('Einkauf');
      await rules.upsert('rewe berlin', category.uuid);

      final suggestions = await service.suggest('  ReWe   BERLIN ');

      expect(suggestions, hasLength(1));
      expect(suggestions.single.categoryUuid, category.uuid);
    },
  );

  test('the suggestion carries the category name and hit count', () async {
    final category = await saveCategory('Freizeit');
    await rules.upsert('amazon', category.uuid);
    await rules.upsert('amazon', category.uuid);
    await rules.upsert('amazon', category.uuid);

    final suggestions = await service.suggest('Amazon');

    expect(suggestions.single.categoryName, 'Freizeit');
    expect(suggestions.single.hitCount, 3);
  });

  test('a rule pointing at a deleted category is dropped', () async {
    final category = await saveCategory('Freizeit');
    await rules.upsert('amazon', category.uuid);
    // A true removal from the collection, unlike `CategoryRepository.delete`,
    // which only archives — see that repository's doc comment.
    await isar.writeTxn(() async {
      await isar.categorys.delete(category.id);
    });

    expect(await service.suggest('Amazon'), isEmpty);
  });

  test('a rule pointing at an archived category is dropped', () async {
    final category = await saveCategory('Freizeit');
    await rules.upsert('amazon', category.uuid);
    await categories.delete(category.uuid);

    expect(await service.suggest('Amazon'), isEmpty);
  });
}
