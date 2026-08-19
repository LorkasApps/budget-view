import 'dart:io';
import 'dart:typed_data';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/persistence/isar_provider.dart';
import 'package:budget_view/features/tagging/domain/tagging_providers.dart';
import 'package:budget_view/features/tagging/domain/tagging_suggest_service.dart';
import 'package:budget_view/features/transaction/domain/transaction_providers.dart';
import 'package:budget_view/features/transaction/import/domain/import_flow_controller.dart';
import 'package:budget_view/features/transaction/import/pdf/parse_result.dart';
import 'package:budget_view/features/transaction/import/pdf/pdf_parser.dart';
import 'package:budget_view/features/transaction/import/pdf/pdf_parser_providers.dart';
import 'package:budget_view/features/transaction/import/pdf/pdf_parser_registry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

/// Yields whatever candidates it is built with; ticket 014 only needs control
/// over the parsed counterparty, not over ranking or failure paths, which
/// `import_flow_controller_test.dart` already covers.
class _StubParser implements PdfParser {
  _StubParser({required this.result});

  @override
  final String id = 'stub';

  final ParseResult result;

  @override
  String get displayName => 'Stub';

  @override
  Future<double> canParse(Uint8List bytes) async => 0.9;

  @override
  Future<ParseResult> parse(Uint8List bytes) async => result;
}

/// Counterparty → learned suggestions, strongest first. A real
/// `LocalTaggingSuggestService` is covered by `tagging_suggest_service_test`;
/// here the controller only needs a source it can call.
class _FakeSuggestService implements TaggingSuggestService {
  _FakeSuggestService(this._byCounterparty);

  final Map<String, List<CategorySuggestion>> _byCounterparty;

  @override
  Future<List<CategorySuggestion>> suggest(String counterparty) async =>
      _byCounterparty[counterparty] ?? const [];
}

void main() {
  late Directory tempDir;
  late Isar isar;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_suggest2_');
    isar = await openAppIsar(directory: tempDir.path);
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  final bytes = Uint8List.fromList([1, 2, 3]);

  ProviderContainer containerWith(
    List<ParsedTransactionCandidate> transactions, {
    Map<String, List<CategorySuggestion>> suggestionsByCounterparty = const {},
  }) {
    final registry = PdfParserRegistry()
      ..register(_StubParser(result: ParseResult(transactions: transactions)));
    final container = ProviderContainer(
      overrides: [
        isarProvider.overrideWithValue(isar),
        pdfParserRegistryProvider.overrideWithValue(registry),
        taggingSuggestServiceProvider.overrideWithValue(
          _FakeSuggestService(suggestionsByCounterparty),
        ),
      ],
    );
    addTearDown(container.dispose);
    // autoDispose provider needs a listener to survive between reads
    final subscription = container.listen(importFlowProvider, (_, _) {});
    addTearDown(subscription.close);
    return container;
  }

  ParsedTransactionCandidate candidate(
    int amountCents,
    String description, {
    String counterparty = 'ACME',
  }) {
    return ParsedTransactionCandidate(
      bookingDate: DateTime(2026, 8, 3),
      amountCents: amountCents,
      description: description,
      counterparty: counterparty,
    );
  }

  test(
    'parseDocument fills the top suggestion and records the alternatives',
    () async {
      final container = containerWith(
        [candidate(-1299, 'REWE', counterparty: 'REWE Berlin')],
        suggestionsByCounterparty: {
          'REWE Berlin': const [
            CategorySuggestion(
              categoryUuid: 'cat-a',
              categoryName: 'Einkauf',
              hitCount: 5,
            ),
            CategorySuggestion(
              categoryUuid: 'cat-b',
              categoryName: 'Sonstiges',
              hitCount: 2,
            ),
          ],
        },
      );
      final controller = container.read(importFlowProvider.notifier);

      await controller.loadDocument(bytes, fileName: 'auszug.pdf');
      await controller.parseDocument();

      final state = container.read(importFlowProvider);
      expect(state.rows.single.categoryUuid, 'cat-a');
      expect(state.rows.single.categorySuggested, isTrue);
      expect(
        state.rowSuggestions[0]?.map((s) => s.categoryUuid),
        ['cat-a', 'cat-b'],
      );
    },
  );

  test('a row whose counterparty matches nothing gets no category', () async {
    final container = containerWith(
      [candidate(5000, 'GEHALT', counterparty: 'Gehalt AG')],
    );
    final controller = container.read(importFlowProvider.notifier);

    await controller.loadDocument(bytes, fileName: 'auszug.pdf');
    await controller.parseDocument();

    final state = container.read(importFlowProvider);
    expect(state.rows.single.categoryUuid, isNull);
    expect(state.rows.single.categorySuggested, isFalse);
    expect(state.rowSuggestions.containsKey(0), isFalse);
  });

  test(
    'a hand-picked category survives a later suggestion re-run',
    () async {
      final container = containerWith(
        [candidate(-1299, 'REWE', counterparty: 'REWE Berlin')],
        suggestionsByCounterparty: {
          'REWE Berlin': const [
            CategorySuggestion(
              categoryUuid: 'cat-a',
              categoryName: 'Einkauf',
              hitCount: 5,
            ),
          ],
        },
      );
      final controller = container.read(importFlowProvider.notifier);

      await controller.loadDocument(bytes, fileName: 'auszug.pdf');
      await controller.parseDocument();
      controller.setRowCategory(0, 'cat-manual');
      await controller.editRow(0, description: 'Edited');

      final row = container.read(importFlowProvider).rows.single;
      expect(row.categoryUuid, 'cat-manual');
      expect(row.categorySuggested, isFalse);
    },
  );

  test(
    'setRowCategory and setCategoryForAll clear categorySuggested',
    () async {
      final container = containerWith(
        [
          candidate(-1299, 'REWE', counterparty: 'REWE Berlin'),
          candidate(5000, 'GEHALT', counterparty: 'Gehalt AG'),
        ],
        suggestionsByCounterparty: {
          'REWE Berlin': const [
            CategorySuggestion(
              categoryUuid: 'cat-a',
              categoryName: 'Einkauf',
              hitCount: 5,
            ),
          ],
        },
      );
      final controller = container.read(importFlowProvider.notifier);

      await controller.loadDocument(bytes, fileName: 'auszug.pdf');
      await controller.parseDocument();
      expect(
        container.read(importFlowProvider).rows[0].categorySuggested,
        isTrue,
      );

      controller.setRowCategory(0, 'cat-a');
      expect(
        container.read(importFlowProvider).rows[0].categorySuggested,
        isFalse,
      );

      controller.setCategoryForAll('cat-b');
      final rows = container.read(importFlowProvider).rows;
      expect(rows.every((row) => !row.categorySuggested), isTrue);
      expect(rows.map((row) => row.categoryUuid), ['cat-b', 'cat-b']);
    },
  );

  test("editing a row's counterparty re-suggests its category", () async {
    final container = containerWith(
      [candidate(-1299, 'REWE', counterparty: 'REWE Berlin')],
      suggestionsByCounterparty: {
        'REWE Berlin': const [
          CategorySuggestion(
            categoryUuid: 'cat-a',
            categoryName: 'Einkauf',
            hitCount: 5,
          ),
        ],
        'Aldi Hamburg': const [
          CategorySuggestion(
            categoryUuid: 'cat-c',
            categoryName: 'Lebensmittel',
            hitCount: 4,
          ),
        ],
      },
    );
    final controller = container.read(importFlowProvider.notifier);

    await controller.loadDocument(bytes, fileName: 'auszug.pdf');
    await controller.parseDocument();
    expect(container.read(importFlowProvider).rows.single.categoryUuid,
        'cat-a');

    await controller.editRow(0, counterparty: 'Aldi Hamburg');

    final row = container.read(importFlowProvider).rows.single;
    expect(row.counterparty, 'Aldi Hamburg');
    expect(row.categoryUuid, 'cat-c');
    expect(row.categorySuggested, isTrue);
  });

  test('persist carries categoryAutoSuggested per row', () async {
    final container = containerWith(
      [
        candidate(-1299, 'REWE', counterparty: 'REWE Berlin'),
        candidate(5000, 'GEHALT', counterparty: 'Gehalt AG'),
      ],
      suggestionsByCounterparty: {
        'REWE Berlin': const [
          CategorySuggestion(
            categoryUuid: 'cat-a',
            categoryName: 'Einkauf',
            hitCount: 5,
          ),
        ],
      },
    );
    final controller = container.read(importFlowProvider.notifier);

    await controller.loadDocument(bytes, fileName: 'auszug.pdf');
    await controller.parseDocument();
    controller.setRowCategory(1, 'cat-manual');
    await controller.setTargetAccount('account-1');
    await controller.persist();

    final saved = await container
        .read(transactionRepositoryProvider)
        .findByAccount('account-1');
    final rewe = saved.firstWhere((t) => t.description == 'REWE');
    final gehalt = saved.firstWhere((t) => t.description == 'GEHALT');
    expect(rewe.categoryAutoSuggested, isTrue);
    expect(rewe.categoryUuid, 'cat-a');
    expect(gehalt.categoryAutoSuggested, isFalse);
    expect(gehalt.categoryUuid, 'cat-manual');
  });
}
