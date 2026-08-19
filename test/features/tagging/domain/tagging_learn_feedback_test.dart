import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_repository.dart';
import 'package:budget_view/features/tagging/domain/tagging_learn_service.dart';
import 'package:budget_view/features/tagging/domain/tagging_rule_repository.dart';
import 'package:budget_view/features/tagging/domain/tagging_suggest_service.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/domain/transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

/// Ticket 014's whole feedback loop: `TaggingLearnService` writes the rules
/// `LocalTaggingSuggestService` reads back, end to end on a real Isar — no
/// fakes on either side, unlike the controller- and widget-level suites.
void main() {
  late Directory tempDir;
  late Isar isar;
  late CategoryRepository categories;
  late TaggingRuleRepository rules;
  late TaggingLearnService learn;
  late LocalTaggingSuggestService suggest;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_feedback_');
    isar = await openAppIsar(directory: tempDir.path);
    final sync = LocalSyncAdapter(isar);
    final transactions = TransactionRepository(isar, sync);
    categories = CategoryRepository(isar, sync, transactions);
    rules = TaggingRuleRepository(isar, sync);
    learn = TaggingLearnService(rules);
    suggest = LocalTaggingSuggestService(rules, categories);
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<Category> saveCategory(String name) =>
      categories.save(Category()..name = name);

  // Bare, unsaved Transaction: only categoryUuid, counterparty and
  // categoryAutoSuggested feed into either service under test here.
  Transaction booking({
    required String? categoryUuid,
    String counterparty = 'REWE Berlin',
    bool categoryAutoSuggested = false,
  }) {
    return Transaction()
      ..categoryUuid = categoryUuid
      ..counterparty = counterparty
      ..categoryAutoSuggested = categoryAutoSuggested;
  }

  test('teaching a pair makes it the suggestion', () async {
    final groceries = await saveCategory('Einkauf');

    await learn.learnFrom(booking(categoryUuid: groceries.uuid));

    final suggestions = await suggest.suggest('REWE Berlin');
    expect(suggestions, hasLength(1));
    expect(suggestions.single.categoryUuid, groceries.uuid);
    expect(suggestions.single.hitCount, 1);
  });

  test('repeating the same pair raises the hit count', () async {
    final groceries = await saveCategory('Einkauf');

    await learn.learnFrom(booking(categoryUuid: groceries.uuid));
    await learn.learnFrom(booking(categoryUuid: groceries.uuid));

    final suggestions = await suggest.suggest('REWE Berlin');
    expect(suggestions.single.hitCount, 2);
  });

  test('an accepted suggestion does not reinforce itself', () async {
    final groceries = await saveCategory('Einkauf');
    await learn.learnFrom(booking(categoryUuid: groceries.uuid));

    // Simulates the form saving the untouched top suggestion: the flag tells
    // the hook this was the machine's own guess, not a user decision.
    await learn.learnFrom(
      booking(categoryUuid: groceries.uuid, categoryAutoSuggested: true),
    );

    final suggestions = await suggest.suggest('REWE Berlin');
    expect(suggestions.single.hitCount, 1);
  });

  test(
    'enough overrides make the override outrank the original',
    () async {
      final groceries = await saveCategory('Einkauf');
      final leisure = await saveCategory('Freizeit');

      for (var i = 0; i < 3; i++) {
        await learn.learnFrom(booking(categoryUuid: groceries.uuid));
      }
      await learn.learnFrom(booking(categoryUuid: leisure.uuid));

      var suggestions = await suggest.suggest('REWE Berlin');
      expect(suggestions.first.categoryUuid, groceries.uuid);
      expect(suggestions.first.hitCount, 3);
      expect(suggestions.last.categoryUuid, leisure.uuid);
      expect(suggestions.last.hitCount, 1);

      // Three more overrides put leisure at 4 hits, decisively ahead of
      // groceries' 3 — no need to lean on the lastAssignedAt tiebreaker.
      for (var i = 0; i < 3; i++) {
        await learn.learnFrom(booking(categoryUuid: leisure.uuid));
      }

      suggestions = await suggest.suggest('REWE Berlin');
      expect(suggestions.first.categoryUuid, leisure.uuid);
      expect(suggestions.first.hitCount, 4);
      expect(suggestions.last.categoryUuid, groceries.uuid);
    },
  );
}
