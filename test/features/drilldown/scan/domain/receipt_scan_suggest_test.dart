import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_providers.dart';
import 'package:budget_view/features/drilldown/scan/domain/receipt_image_source.dart';
import 'package:budget_view/features/drilldown/scan/domain/receipt_line_item_parser.dart';
import 'package:budget_view/features/drilldown/scan/domain/receipt_scan_providers.dart';
import 'package:budget_view/features/tagging/data/tagging_rule.dart';
import 'package:budget_view/features/tagging/domain/tagging_providers.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/domain/transaction_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'scan_test_support.dart';

/// The article-rule side of ticket 056: what the scan flow suggests per position
/// and what it learns back at confirm.
///
/// Real rules and real categories on a real (test) Isar rather than a faked
/// suggest service. Two reasons: the description keyspace and the counterparty
/// one must stay apart end to end, and `suggest` drops a rule whose category does
/// not exist — seeding a bare uuid would make every test here pass for the wrong
/// reason.
void main() {
  late Directory tempDir;
  late Isar isar;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_scansuggest_');
    isar = await openAppIsar(directory: tempDir.path);
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<Transaction> savedExpense(ProviderContainer container) =>
      container.read(transactionRepositoryProvider).save(expenseTransaction());

  Future<String> savedCategory(ProviderContainer container, String name) async {
    final saved = await container
        .read(categoryRepositoryProvider)
        .save(Category()..name = name);
    return saved.uuid;
  }

  /// Seeds an article rule [times] over, so a test can build a strict winner or
  /// a deliberate tie.
  Future<void> seedArticleRule(
    ProviderContainer container, {
    required String article,
    required String categoryUuid,
    int times = 1,
  }) async {
    final rules = container.read(taggingRuleRepositoryProvider);
    for (var i = 0; i < times; i++) {
      await rules.upsert(
        article,
        categoryUuid,
        matchField: TaggingMatchField.description,
      );
    }
  }

  Future<void> scan(ProviderContainer container) async {
    final transaction = await savedExpense(container);
    await container.read(receiptScanFlowProvider.notifier).startScan(
          transaction: transaction,
          source: ScanSource.gallery,
        );
  }

  LineItemCandidate candidateNamed(ProviderContainer container, String name) =>
      container
          .read(receiptScanFlowProvider)
          .candidates
          .firstWhere((candidate) => candidate.description == name);

  test('an unambiguous article rule fills the row and marks it as a guess',
      () async {
    final container = containerWith(isar: isar);
    final groceries = await savedCategory(container, 'Einkauf');
    await seedArticleRule(
      container,
      article: 'milch',
      categoryUuid: groceries,
    );
    await scan(container);

    final milch = candidateNamed(container, 'Milch');
    expect(milch.categoryUuid, groceries);
    expect(milch.categorySuggested, isTrue);
    expect(container.read(receiptScanFlowProvider).candidateSuggestions[0],
        hasLength(1));
  });

  test('a position nothing was learned for stays uncategorized', () async {
    final container = containerWith(isar: isar);
    final groceries = await savedCategory(container, 'Einkauf');
    await seedArticleRule(
      container,
      article: 'milch',
      categoryUuid: groceries,
    );
    await scan(container);

    final brot = candidateNamed(container, 'Brot');
    expect(brot.categoryUuid, isNull);
    expect(brot.categorySuggested, isFalse);
    expect(
      container.read(receiptScanFlowProvider).candidateSuggestions.containsKey(1),
      isFalse,
    );
  });

  test('a tie fills nothing but still offers both alternatives', () async {
    final container = containerWith(isar: isar);
    final groceries = await savedCategory(container, 'Einkauf');
    final drinks = await savedCategory(container, 'Getränke');
    await seedArticleRule(container, article: 'milch', categoryUuid: groceries);
    await seedArticleRule(container, article: 'milch', categoryUuid: drinks);
    await scan(container);

    expect(candidateNamed(container, 'Milch').categoryUuid, isNull);
    expect(container.read(receiptScanFlowProvider).candidateSuggestions[0],
        hasLength(2));
  });

  test('a strictly stronger rule wins over its runner-up', () async {
    final container = containerWith(isar: isar);
    final groceries = await savedCategory(container, 'Einkauf');
    final drinks = await savedCategory(container, 'Getränke');
    await seedArticleRule(
      container,
      article: 'milch',
      categoryUuid: groceries,
      times: 2,
    );
    await seedArticleRule(container, article: 'milch', categoryUuid: drinks);
    await scan(container);

    expect(candidateNamed(container, 'Milch').categoryUuid, groceries);
  });

  test('a counterparty rule of the same text never reaches a position',
      () async {
    final container = containerWith(isar: isar);
    // The shop is called Milch too, and its category really exists — so if this
    // passes it is the keyspace keeping them apart, not the stale-rule filter.
    final shop = await savedCategory(container, 'Laden');
    await container.read(taggingRuleRepositoryProvider).upsert('milch', shop);
    await scan(container);

    expect(candidateNamed(container, 'Milch').categoryUuid, isNull);
  });

  test('a position without a description is offered nothing', () async {
    final container = containerWith(
      isar: isar,
      parser: FakeReceiptLineItemParser([
        LineItemCandidate(
          amountCents: 119,
          parseState: LineItemParseState.ambiguous,
        ),
      ]),
    );
    final groceries = await savedCategory(container, 'Einkauf');
    await seedArticleRule(
      container,
      article: 'milch',
      categoryUuid: groceries,
    );
    await scan(container);

    final state = container.read(receiptScanFlowProvider);
    expect(state.candidates.single.categoryUuid, isNull);
    expect(state.candidateSuggestions, isEmpty);
  });

  group('learning back at confirm', () {
    Future<List<TaggingRule>> articleRules(
      ProviderContainer container,
      String article,
    ) =>
        container.read(taggingRuleRepositoryProvider).findByMatch(
              article,
              matchField: TaggingMatchField.description,
            );

    test('a hand-set category on a position writes an article rule', () async {
      final container = containerWith(isar: isar);
      final groceries = await savedCategory(container, 'Einkauf');
      await scan(container);

      final controller = container.read(receiptScanFlowProvider.notifier);
      final edited = [
        for (final candidate
            in container.read(receiptScanFlowProvider).candidates)
          candidate.description == 'Milch'
              ? candidate.withCategory(groceries)
              : candidate,
      ];
      await controller.confirm(edited: edited);

      expect((await articleRules(container, 'milch')).single.categoryUuid,
          groceries);
    });

    test('an untouched suggestion teaches nothing back', () async {
      final container = containerWith(isar: isar);
      final groceries = await savedCategory(container, 'Einkauf');
      await seedArticleRule(
        container,
        article: 'milch',
        categoryUuid: groceries,
      );
      await scan(container);
      await container.read(receiptScanFlowProvider.notifier).confirm();

      // Still the one seeded hit: reinforcing its own guess is exactly what the
      // categorySuggested flag exists to prevent.
      expect((await articleRules(container, 'milch')).single.hitCount, 1);
    });

    test('a position that inherits the booking teaches nothing', () async {
      final container = containerWith(isar: isar);
      await scan(container);
      await container.read(receiptScanFlowProvider.notifier).confirm();

      expect(
        await container.read(taggingRuleRepositoryProvider).findAll(),
        isEmpty,
      );
    });

    test('an override of a suggestion raises the chosen category', () async {
      final container = containerWith(isar: isar);
      final groceries = await savedCategory(container, 'Einkauf');
      final drinks = await savedCategory(container, 'Getränke');
      await seedArticleRule(
        container,
        article: 'milch',
        categoryUuid: groceries,
      );
      await scan(container);

      final controller = container.read(receiptScanFlowProvider.notifier);
      final edited = [
        for (final candidate
            in container.read(receiptScanFlowProvider).candidates)
          candidate.description == 'Milch'
              ? candidate.withCategory(drinks)
              : candidate,
      ];
      await controller.confirm(edited: edited);

      final found = await articleRules(container, 'milch');
      expect(found, hasLength(2));
      expect(found.firstWhere((r) => r.categoryUuid == drinks).hitCount, 1);
    });
  });

  test('a PDF receipt suggests exactly as a photo does', () async {
    final container = containerWith(isar: isar);
    final groceries = await savedCategory(container, 'Einkauf');
    await seedArticleRule(
      container,
      article: 'milch',
      categoryUuid: groceries,
    );
    final transaction = await savedExpense(container);
    await container
        .read(receiptScanFlowProvider.notifier)
        .startPdfScan(transaction: transaction);

    final milch = candidateNamed(container, 'Milch');
    expect(milch.categoryUuid, groceries);
    expect(milch.categorySuggested, isTrue);
  });
}
