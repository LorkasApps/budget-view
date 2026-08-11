import 'dart:io';
import 'dart:typed_data';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/persistence/isar_provider.dart';
import 'package:budget_view/features/transaction/domain/transaction_providers.dart';
import 'package:budget_view/features/transaction/import/domain/import_flow_controller.dart';
import 'package:budget_view/features/transaction/import/pdf/parse_result.dart';
import 'package:budget_view/features/transaction/import/pdf/pdf_parser.dart';
import 'package:budget_view/features/transaction/import/pdf/pdf_parser_providers.dart';
import 'package:budget_view/features/transaction/import/pdf/pdf_parser_registry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

class _StubParser implements PdfParser {
  _StubParser({
    this.id = 'stub',
    this.confidence = 0.9,
    this.result = const ParseResult(transactions: []),
    this.throwOnParse = false,
  });

  @override
  final String id;

  final double confidence;
  final ParseResult result;
  final bool throwOnParse;

  @override
  String get displayName => 'Stub $id';

  @override
  Future<double> canParse(Uint8List bytes) async => confidence;

  @override
  Future<ParseResult> parse(Uint8List bytes) async {
    if (throwOnParse) throw StateError('parse exploded');
    return result;
  }
}

void main() {
  late Directory tempDir;
  late Isar isar;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_import_');
    isar = await openAppIsar(directory: tempDir.path);
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  final bytes = Uint8List.fromList([1, 2, 3]);

  ProviderContainer containerWith(PdfParserRegistry registry) {
    final container = ProviderContainer(
      overrides: [
        isarProvider.overrideWithValue(isar),
        pdfParserRegistryProvider.overrideWithValue(registry),
      ],
    );
    addTearDown(container.dispose);
    // autoDispose provider needs a listener to survive between reads
    final subscription = container.listen(importFlowProvider, (_, _) {});
    addTearDown(subscription.close);
    return container;
  }

  ParsedTransactionCandidate candidate(int amountCents, String description) {
    return ParsedTransactionCandidate(
      bookingDate: DateTime(2026, 8, 3),
      amountCents: amountCents,
      description: description,
      counterparty: 'ACME',
    );
  }

  PdfParserRegistry registryYielding(
    List<ParsedTransactionCandidate> transactions, {
    List<String> warnings = const [],
  }) {
    return PdfParserRegistry()
      ..register(
        _StubParser(
          result: ParseResult(transactions: transactions, warnings: warnings),
        ),
      );
  }

  test('loadDocument preselects the highest ranked parser', () async {
    final registry = PdfParserRegistry()
      ..register(_StubParser(id: 'low', confidence: 0.2))
      ..register(_StubParser(id: 'high', confidence: 0.8));
    final container = containerWith(registry);

    await container
        .read(importFlowProvider.notifier)
        .loadDocument(bytes, fileName: 'auszug.pdf');

    final state = container.read(importFlowProvider);
    expect(state.fileName, 'auszug.pdf');
    expect(state.ranking.length, 2);
    expect(state.selectedParserId, 'high');
    expect(state.busy, isFalse);
  });

  test('parseDocument turns candidates into rows, all included', () async {
    final container = containerWith(
      registryYielding(
        [candidate(-1299, 'REWE'), candidate(5000, 'GEHALT')],
        warnings: const ['Zeile 7 unlesbar'],
      ),
    );
    final controller = container.read(importFlowProvider.notifier);

    await controller.loadDocument(bytes, fileName: 'auszug.pdf');
    await controller.parseDocument();

    final state = container.read(importFlowProvider);
    expect(state.rows.length, 2);
    expect(state.rows.every((row) => row.included), isTrue);
    expect(state.includedCount, 2);
    expect(state.warnings, ['Zeile 7 unlesbar']);
  });

  test('toggleRow excludes a row, editRow overwrites only given fields',
      () async {
    final container = containerWith(
      registryYielding([candidate(-1299, 'REWE'), candidate(5000, 'GEHALT')]),
    );
    final controller = container.read(importFlowProvider.notifier);

    await controller.loadDocument(bytes, fileName: 'auszug.pdf');
    await controller.parseDocument();
    controller.toggleRow(0);
    controller.editRow(1, amountCents: -999, description: 'EDEKA');

    final state = container.read(importFlowProvider);
    expect(state.rows[0].included, isFalse);
    expect(state.includedCount, 1);
    expect(state.rows[1].amountCents, -999);
    expect(state.rows[1].description, 'EDEKA');
    expect(state.rows[1].counterparty, 'ACME');
  });

  test('persist writes only included rows and reports a summary', () async {
    final container = containerWith(
      registryYielding(
        [candidate(-1299, 'REWE'), candidate(5000, 'GEHALT')],
        warnings: const ['Zeile 7 unlesbar'],
      ),
    );
    final controller = container.read(importFlowProvider.notifier);

    await controller.loadDocument(bytes, fileName: 'auszug.pdf');
    await controller.parseDocument();
    controller.toggleRow(1);
    await controller.persist(accountUuid: 'account-1');

    final saved = await container
        .read(transactionRepositoryProvider)
        .findByAccount('account-1');
    expect(saved.length, 1);
    expect(saved.single.description, 'REWE');
    expect(saved.single.amountCents, -1299);
    expect(saved.single.uuid, isNotEmpty);

    final summary = container.read(importFlowProvider).summary;
    expect(summary?.imported, 1);
    expect(summary?.skipped, 1);
    expect(summary?.warnings, 1);
  });

  test('a throwing parser surfaces an error instead of rows', () async {
    final container = containerWith(
      PdfParserRegistry()..register(_StubParser(throwOnParse: true)),
    );
    final controller = container.read(importFlowProvider.notifier);

    await controller.loadDocument(bytes, fileName: 'auszug.pdf');
    await controller.parseDocument();

    final state = container.read(importFlowProvider);
    expect(state.rows, isEmpty);
    expect(state.error, contains('Parsen fehlgeschlagen'));
    expect(state.busy, isFalse);
  });

  test('without a registered parser nothing is selected and parse is a no-op',
      () async {
    final container = containerWith(PdfParserRegistry());
    final controller = container.read(importFlowProvider.notifier);

    await controller.loadDocument(bytes, fileName: 'auszug.pdf');
    await controller.parseDocument();

    final state = container.read(importFlowProvider);
    expect(state.selectedParserId, isNull);
    expect(state.rows, isEmpty);
    expect(state.error, isEmpty);
  });

  test('persist with no included rows writes nothing', () async {
    final container = containerWith(registryYielding([candidate(-500, 'DM')]));
    final controller = container.read(importFlowProvider.notifier);

    await controller.loadDocument(bytes, fileName: 'auszug.pdf');
    await controller.parseDocument();
    controller.toggleRow(0);
    await controller.persist(accountUuid: 'account-1');

    final saved = await container
        .read(transactionRepositoryProvider)
        .findByAccount('account-1');
    expect(saved, isEmpty);
    expect(container.read(importFlowProvider).summary, isNull);
  });
}
