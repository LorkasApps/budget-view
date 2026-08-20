import 'package:budget_view/core/format/date_format.dart';
import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_providers.dart';
import 'package:budget_view/features/tagging/data/tagging_rule.dart';
import 'package:budget_view/features/tagging/domain/tagging_providers.dart';
import 'package:budget_view/features/tagging/domain/tagging_rule_repository.dart';
import 'package:budget_view/features/tagging/presentation/tagging_rules_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records `remap` and `delete` calls; `implements` (not `extends`) means the
/// real constructor, which wants a working `Isar` and `SyncAdapter`, is never
/// called.
class _RecordingTaggingRuleRepository implements TaggingRuleRepository {
  final List<({String ruleUuid, String categoryUuid})> remapped = [];
  final List<String> deleted = [];

  @override
  Future<void> remap(String uuid, String categoryUuid) async {
    remapped.add((ruleUuid: uuid, categoryUuid: categoryUuid));
  }

  @override
  Future<void> delete(String uuid) async {
    deleted.add(uuid);
  }

  @override
  Future<TaggingRule> upsert(
    String matchValueNorm,
    String categoryUuid, {
    TaggingMatchField matchField = TaggingMatchField.counterparty,
  }) async {
    throw UnsupportedError('not exercised by this screen');
  }

  @override
  Future<List<TaggingRule>> findByCounterparty(String matchValueNorm) async {
    return const [];
  }

  @override
  Future<List<TaggingRule>> findAll() async {
    return const [];
  }

  @override
  Future<TaggingRule?> findByUuid(String uuid) async {
    return null;
  }
}

TaggingRule _rule({
  required String uuid,
  required String matchValueNorm,
  required String categoryUuid,
  int hitCount = 1,
  DateTime? lastAssignedAt,
}) {
  final now = DateTime(2026, 3, 1);
  return TaggingRule()
    ..uuid = uuid
    ..matchValueNorm = matchValueNorm
    ..categoryUuid = categoryUuid
    ..hitCount = hitCount
    ..lastAssignedAt = lastAssignedAt ?? now
    ..createdAt = now
    ..updatedAt = now;
}

Category _category({
  required String uuid,
  required String name,
  bool archived = false,
}) {
  final now = DateTime(2026, 3, 1);
  return Category()
    ..uuid = uuid
    ..name = name
    ..archived = archived
    ..createdAt = now
    ..updatedAt = now;
}

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// A fling rather than a drag: it carries velocity, so the dismissal fires
  /// without the swipe having to clear the 40 % width threshold on its own.
  Future<void> swipeAway(WidgetTester tester, Finder row) async {
    await tester.fling(row, const Offset(-800, 0), 2000);
    await tester.pumpAndSettle();
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required List<TaggingRule> rules,
    required List<Category> categories,
    required _RecordingTaggingRuleRepository repository,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taggingRulesProvider.overrideWith((ref) => Stream.value(rules)),
          categoriesProvider.overrideWith(
            (ref, includeArchived) => Stream.value(categories),
          ),
          taggingRuleRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: TaggingRulesScreen()),
      ),
    );
    await settle(tester);
  }

  testWidgets('a row shows counterparty, category, hit count and date', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      rules: [
        _rule(
          uuid: 'r1',
          matchValueNorm: 'rewe berlin',
          categoryUuid: 'cat-groceries',
          hitCount: 3,
        ),
      ],
      categories: [_category(uuid: 'cat-groceries', name: 'Lebensmittel')],
      repository: _RecordingTaggingRuleRepository(),
    );

    expect(find.text('rewe berlin'), findsOneWidget);
    final subtitle = tester
        .widget<Text>(find.textContaining('Lebensmittel'))
        .data!;
    expect(subtitle, contains('Lebensmittel'));
    expect(subtitle, contains('3×'));
    expect(subtitle, contains(formatDateDe(DateTime(2026, 3, 1))));
  });

  testWidgets('sorting by Gegenseite orders rows alphabetically', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      rules: [
        _rule(
          uuid: 'r1',
          matchValueNorm: 'zoo fachhandel',
          categoryUuid: 'cat-a',
          hitCount: 5,
        ),
        _rule(
          uuid: 'r2',
          matchValueNorm: 'aral tankstelle',
          categoryUuid: 'cat-a',
          hitCount: 1,
        ),
      ],
      categories: [_category(uuid: 'cat-a', name: 'Sonstiges')],
      repository: _RecordingTaggingRuleRepository(),
    );

    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gegenseite'));
    await tester.pumpAndSettle();

    final aralY = tester.getTopLeft(find.text('aral tankstelle')).dy;
    final zooY = tester.getTopLeft(find.text('zoo fachhandel')).dy;
    expect(aralY, lessThan(zooY));
  });

  testWidgets('sorting by Zuletzt genutzt orders rows by lastAssignedAt', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      rules: [
        // supplied strongest-first, like the real provider would.
        _rule(
          uuid: 'r2',
          matchValueNorm: 'strong but old',
          categoryUuid: 'cat-a',
          hitCount: 9,
          lastAssignedAt: DateTime(2026, 1, 1),
        ),
        _rule(
          uuid: 'r1',
          matchValueNorm: 'weak but recent',
          categoryUuid: 'cat-a',
          hitCount: 1,
          lastAssignedAt: DateTime(2026, 3, 10),
        ),
      ],
      categories: [_category(uuid: 'cat-a', name: 'Sonstiges')],
      repository: _RecordingTaggingRuleRepository(),
    );

    // strength order first: the stronger rule sits above the weaker one.
    final strongYBefore = tester.getTopLeft(find.text('strong but old')).dy;
    final weakYBefore = tester.getTopLeft(find.text('weak but recent')).dy;
    expect(strongYBefore, lessThan(weakYBefore));

    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zuletzt genutzt'));
    await tester.pumpAndSettle();

    final weakYAfter = tester.getTopLeft(find.text('weak but recent')).dy;
    final strongYAfter = tester.getTopLeft(find.text('strong but old')).dy;
    expect(weakYAfter, lessThan(strongYAfter));
  });

  testWidgets('a rule pointing at an archived category renders as stale', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      rules: [
        _rule(uuid: 'r1', matchValueNorm: 'stale shop', categoryUuid: 'cat-a'),
        _rule(
          uuid: 'r2',
          matchValueNorm: 'healthy shop',
          categoryUuid: 'cat-b',
        ),
      ],
      categories: [
        _category(uuid: 'cat-a', name: 'Archiviert', archived: true),
        _category(uuid: 'cat-b', name: 'Aktiv'),
      ],
      repository: _RecordingTaggingRuleRepository(),
    );

    final staleTile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('stale shop'),
        matching: find.byType(ListTile),
      ),
    );
    final healthyTile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('healthy shop'),
        matching: find.byType(ListTile),
      ),
    );

    expect((staleTile.subtitle! as Text).data, contains('veraltet'));
    expect(staleTile.trailing, isNotNull);
    expect((healthyTile.subtitle! as Text).data, isNot(contains('veraltet')));
    expect(healthyTile.trailing, isNull);
  });

  testWidgets('tapping a row and picking a different category remaps it', (
    tester,
  ) async {
    final repository = _RecordingTaggingRuleRepository();
    await pumpScreen(
      tester,
      rules: [
        _rule(uuid: 'r1', matchValueNorm: 'rewe berlin', categoryUuid: 'cat-a'),
      ],
      categories: [
        _category(uuid: 'cat-a', name: 'Lebensmittel'),
        _category(uuid: 'cat-b', name: 'Freizeit'),
      ],
      repository: repository,
    );

    await tester.tap(find.text('rewe berlin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Freizeit'));
    await tester.pumpAndSettle();

    expect(repository.remapped, [(ruleUuid: 'r1', categoryUuid: 'cat-b')]);
  });

  testWidgets('swiping a row and confirming deletes it', (tester) async {
    final repository = _RecordingTaggingRuleRepository();
    await pumpScreen(
      tester,
      rules: [
        _rule(uuid: 'r1', matchValueNorm: 'rewe berlin', categoryUuid: 'cat-a'),
      ],
      categories: [_category(uuid: 'cat-a', name: 'Lebensmittel')],
      repository: repository,
    );

    await swipeAway(tester, find.text('rewe berlin'));
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(repository.deleted, ['r1']);
  });

  testWidgets(
    'the collective delete removes only stale rules, keeping the healthy one',
    (tester) async {
      final repository = _RecordingTaggingRuleRepository();
      await pumpScreen(
        tester,
        rules: [
          _rule(uuid: 'r1', matchValueNorm: 'stale one', categoryUuid: 'cat-a'),
          _rule(uuid: 'r2', matchValueNorm: 'stale two', categoryUuid: 'cat-b'),
          _rule(
            uuid: 'r3',
            matchValueNorm: 'healthy one',
            categoryUuid: 'cat-c',
          ),
        ],
        categories: [
          _category(uuid: 'cat-a', name: 'Archiviert A', archived: true),
          _category(uuid: 'cat-c', name: 'Aktiv'),
          // cat-b absent on purpose: an unresolvable category is stale too.
        ],
        repository: repository,
      );

      expect(find.textContaining('2 Regeln'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('2 veraltete Regeln löschen?'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
      await tester.pumpAndSettle();

      expect(repository.deleted, containsAll(['r1', 'r2']));
      expect(repository.deleted, isNot(contains('r3')));
      expect(repository.deleted.length, 2);
    },
  );

  testWidgets('an empty rule list shows the empty-state hint', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      rules: const [],
      categories: const [],
      repository: _RecordingTaggingRuleRepository(),
    );

    expect(find.textContaining('Noch keine Regeln gelernt.'), findsOneWidget);
  });
}
