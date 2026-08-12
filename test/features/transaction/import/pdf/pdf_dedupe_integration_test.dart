import 'dart:io';
import 'dart:typed_data';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/persistence/isar_provider.dart';
import 'package:budget_view/features/import/data/imported_source_kind.dart';
import 'package:budget_view/features/import/domain/import_providers.dart';
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
  _StubParser(this.candidates);

  final List<ParsedTransactionCandidate> candidates;

  @override
  String get id => 'stub';

  @override
  String get displayName => 'Stub';

  @override
  Future<double> canParse(Uint8List bytes) async => 0.9;

  @override
  Future<ParseResult> parse(Uint8List bytes) async =>
      ParseResult(transactions: candidates);
}

ParsedTransactionCandidate _candidate({
  int amountCents = -1299,
  DateTime? bookingDate,
  String counterparty = 'REWE',
  String description = 'Einkauf',
}) {
  return ParsedTransactionCandidate(
    bookingDate: bookingDate ?? DateTime(2026, 8, 3),
    amountCents: amountCents,
    description: description,
    counterparty: counterparty,
  );
}

void main() {
  late Directory tempDir;
  late Isar isar;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_pdfdupe_');
    isar = await openAppIsar(directory: tempDir.path);
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  final bytes = Uint8List.fromList([1, 2, 3, 4]);
  final otherBytes = Uint8List.fromList([9, 9, 9]);

  ProviderContainer containerFor(List<ParsedTransactionCandidate> candidates) {
    final container = ProviderContainer(
      overrides: [
        isarProvider.overrideWithValue(isar),
        pdfParserRegistryProvider.overrideWithValue(
          PdfParserRegistry()..register(_StubParser(candidates)),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(importFlowProvider, (_, _) {});
    addTearDown(subscription.close);
    return container;
  }

  Future<ImportFlowController> run(
    ProviderContainer container, {
    Uint8List? source,
    String accountUuid = 'account-1',
  }) async {
    final controller = container.read(importFlowProvider.notifier);
    await controller.setTargetAccount(accountUuid);
    await controller.loadDocument(source ?? bytes, fileName: 'auszug.pdf');
    await controller.parseDocument();
    return controller;
  }

  test('a document never seen before raises no warning', () async {
    final container = containerFor([_candidate()]);
    await run(container);

    final state = container.read(importFlowProvider);
    expect(state.documentSeenBefore, isFalse);
    expect(state.contentHash, hasLength(64));
    expect(state.suspiciousCount, 0);
    expect(state.newCount, 1);
  });

  test('re-importing the same file reports the earlier import', () async {
    final first = containerFor([_candidate()]);
    final firstController = await run(first);
    await firstController.persist();

    final second = containerFor([_candidate()]);
    await run(second);

    final state = second.read(importFlowProvider);
    expect(state.documentSeenBefore, isTrue);
    expect(state.documentMatches.single.transactionsProduced, 1);
    expect(state.documentMatches.single.filename, 'auszug.pdf');
  });

  test('a different file is not flagged as a re-import', () async {
    final first = containerFor([_candidate()]);
    await (await run(first)).persist();

    final second = containerFor([_candidate()]);
    await run(second, source: otherBytes);

    expect(second.read(importFlowProvider).documentSeenBefore, isFalse);
  });

  test('a row matching an existing booking is flagged', () async {
    final seed = containerFor([_candidate()]);
    await (await run(seed)).persist();

    final container = containerFor([_candidate(), _candidate(amountCents: -50)]);
    await run(container, source: otherBytes);

    final state = container.read(importFlowProvider);
    expect(state.isSuspicious(0), isTrue);
    expect(state.isSuspicious(1), isFalse);
    expect(state.rowMatches[0], hasLength(1));
    expect(state.suspiciousCount, 1);
    expect(state.newCount, 1);
  });

  test('matches are scoped to the target account', () async {
    final seed = containerFor([_candidate()]);
    await (await run(seed, accountUuid: 'account-1')).persist();

    final container = containerFor([_candidate()]);
    await run(container, source: otherBytes, accountUuid: 'account-2');
    expect(container.read(importFlowProvider).isSuspicious(0), isFalse);

    await container
        .read(importFlowProvider.notifier)
        .setTargetAccount('account-1');
    expect(container.read(importFlowProvider).isSuspicious(0), isTrue);
  });

  test('two identical rows in one document flag each other', () async {
    final container = containerFor([_candidate(), _candidate()]);
    await run(container);

    final state = container.read(importFlowProvider);
    expect(state.intraBatchDuplicates, {0, 1});
    expect(state.suspiciousCount, 2);
    expect(state.newCount, 0);
  });

  test('editing a row off the duplicate hash clears its flag', () async {
    final container = containerFor([_candidate(), _candidate()]);
    final controller = await run(container);
    expect(container.read(importFlowProvider).intraBatchDuplicates, {0, 1});

    await controller.editRow(1, amountCents: -777);

    expect(container.read(importFlowProvider).intraBatchDuplicates, isEmpty);
    expect(container.read(importFlowProvider).suspiciousCount, 0);
  });

  test('persist records one ImportedSource with the included count', () async {
    final container = containerFor([_candidate(), _candidate(amountCents: -50)]);
    final controller = await run(container);
    controller.toggleRow(1);
    await controller.persist();

    final sources =
        await container.read(importedSourceRepositoryProvider).findAll();
    expect(sources, hasLength(1));
    expect(sources.single.kind, ImportedSourceKind.pdf);
    expect(sources.single.filename, 'auszug.pdf');
    expect(sources.single.transactionsProduced, 1);
    expect(sources.single.note, isNull);
  });

  test('importing despite the warning is recorded on the row', () async {
    final first = containerFor([_candidate()]);
    await (await run(first)).persist();

    final second = containerFor([_candidate()]);
    final controller = await run(second);
    await controller.persist();

    final sources =
        await second.read(importedSourceRepositoryProvider).findAll();
    expect(sources, hasLength(2));
    expect(sources.first.note, 'Erneuter Import trotz Warnung');
  });

  test('persisted rows carry the hash the preview warned about', () async {
    final container = containerFor([_candidate()]);
    final controller = await run(container);
    final previewHash = container.read(importFlowProvider).rows.single.dedupeHash;
    await controller.persist();

    final saved = await container
        .read(transactionRepositoryProvider)
        .findByAccount('account-1');
    expect(saved.single.dedupeHash, previewHash);
  });

  test('a soft-deleted booking no longer triggers a warning', () async {
    final seed = containerFor([_candidate()]);
    await (await run(seed)).persist();
    final saved = await seed
        .read(transactionRepositoryProvider)
        .findByAccount('account-1');
    await seed
        .read(transactionRepositoryProvider)
        .softDelete(saved.single.uuid);

    final container = containerFor([_candidate()]);
    await run(container, source: otherBytes);

    expect(container.read(importFlowProvider).isSuspicious(0), isFalse);
  });
}
