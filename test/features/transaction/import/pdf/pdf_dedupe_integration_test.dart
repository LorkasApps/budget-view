import 'dart:io';
import 'dart:typed_data';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/persistence/isar_provider.dart';
import 'package:budget_view/features/import/data/imported_source_kind.dart';
import 'package:budget_view/features/import/domain/import_providers.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
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

  group('mirror leg from a booked transfer (ticket 048)', () {
    /// The pair ticket 042 writes: the source leg on one account and the mirror
    /// the app booked on the other, linked both ways. The mirror is what a later
    /// import of the target account's own statement can meet a second time.
    Future<String> seedPair(
      ProviderContainer container, {
      DateTime? bookingDate,
      String? categoryUuid,
      String note = '',
    }) async {
      final repository = container.read(transactionRepositoryProvider);
      final date = bookingDate ?? DateTime(2026, 8, 3);
      final source = await repository.save(
        Transaction()
          ..accountUuid = 'account-2'
          ..amountCents = -25000
          ..bookingDate = date
          ..description = 'Umbuchung nach Cashkonto'
          ..counterparty = 'Cashkonto'
          ..kind = TransactionKind.transfer,
      );
      final mirror = await repository.save(
        Transaction()
          ..accountUuid = 'account-1'
          ..amountCents = 25000
          ..bookingDate = date
          ..description = 'Umbuchung von Girokonto'
          ..counterparty = 'Girokonto'
          ..categoryUuid = categoryUuid
          ..note = note
          ..kind = TransactionKind.transfer
          ..counterpartUuid = source.uuid,
      );
      source.counterpartUuid = mirror.uuid;
      await repository.save(source);
      return mirror.uuid;
    }

    /// What the receiving bank prints for the same movement: its own wording, and
    /// two days later than the app booked it.
    ParsedTransactionCandidate bankRow({DateTime? bookingDate}) => _candidate(
          amountCents: 25000,
          bookingDate: bookingDate ?? DateTime(2026, 8, 5),
          counterparty: 'ING-DiBa',
          description: 'Uebertrag Girokonto',
        );

    test('a row meeting an app-written mirror leg is flagged as such', () async {
      final container = containerFor([bankRow()]);
      await seedPair(container);
      await run(container);

      final state = container.read(importFlowProvider);
      expect(state.hasMirrorMatch(0), isTrue);
      expect(state.rowMirrorMatches[0], hasLength(1));
      // The hash layer cannot see it: the bank writes another counterparty.
      expect(state.hasHashDuplicate(0), isFalse);
      expect(state.isSuspicious(0), isTrue);
    });

    test('an ordinary booking with the same figures is no mirror match',
        () async {
      final container = containerFor([bankRow()]);
      await container.read(transactionRepositoryProvider).save(
            Transaction()
              ..accountUuid = 'account-1'
              ..amountCents = 25000
              ..bookingDate = DateTime(2026, 8, 5)
              ..description = 'Gehalt'
              ..counterparty = 'Arbeitgeber',
          );
      await run(container);

      expect(container.read(importFlowProvider).hasMirrorMatch(0), isFalse);
    });

    test('a booking date outside the window is no mirror match', () async {
      final container = containerFor([bankRow()]);
      // Six days before the imported row, one past the ±5 window.
      await seedPair(container, bookingDate: DateTime(2026, 7, 30));
      await run(container);

      expect(container.read(importFlowProvider).hasMirrorMatch(0), isFalse);
    });

    test('Ersetzen takes the bank fields and keeps what the user put there',
        () async {
      final container = containerFor([bankRow()]);
      final mirrorUuid = await seedPair(
        container,
        categoryUuid: 'cat-1',
        note: 'Notiz bleibt',
      );
      final controller = await run(container);
      await controller.persist();

      final repository = container.read(transactionRepositoryProvider);
      final onTarget = await repository.findByAccount('account-1');
      expect(onTarget, hasLength(1), reason: 'no second booking is created');

      final leg = onTarget.single;
      expect(leg.uuid, mirrorUuid);
      expect(leg.description, 'Uebertrag Girokonto');
      expect(leg.counterparty, 'ING-DiBa');
      expect(leg.amountCents, 25000);
      expect(leg.bookingDate, DateTime(2026, 8, 5));
      expect(leg.categoryUuid, 'cat-1');
      expect(leg.note, 'Notiz bleibt');
      expect(leg.kind, TransactionKind.transfer);
      expect(leg.counterpartUuid, isNotNull);
    });

    test('Ersetzen changes nothing on the other leg', () async {
      final container = containerFor([bankRow()]);
      await seedPair(container);
      await (await run(container)).persist();

      final source = await container
          .read(transactionRepositoryProvider)
          .findByAccount('account-2');
      expect(source.single.bookingDate, DateTime(2026, 8, 3));
      expect(source.single.amountCents, -25000);
      expect(source.single.description, 'Umbuchung nach Cashkonto');
    });

    test('Beide behalten imports the row and leaves both dates standing',
        () async {
      final container = containerFor([bankRow()]);
      await seedPair(container);
      final controller = await run(container);
      controller.setKeepBothLegs(0, true);
      await controller.persist();

      final onTarget = await container
          .read(transactionRepositoryProvider)
          .findByAccount('account-1');
      expect(onTarget, hasLength(2));
      expect(
        onTarget.map((booking) => booking.bookingDate).toSet(),
        {DateTime(2026, 8, 3), DateTime(2026, 8, 5)},
      );
    });

    test('a leg already replaced is a plain duplicate on the next import',
        () async {
      final first = containerFor([bankRow()]);
      await seedPair(first);
      await (await run(first)).persist();

      final second = containerFor([bankRow()]);
      await run(second, source: otherBytes);
      final state = second.read(importFlowProvider);
      // The replaced leg now carries the bank's fields, so it hashes like the
      // row and the ordinary duplicate path owns it.
      expect(state.hasMirrorMatch(0), isFalse);
      expect(state.hasHashDuplicate(0), isTrue);
    });

    test('editing a row off its mirror leg drops the keep-both choice',
        () async {
      final container = containerFor([bankRow()]);
      await seedPair(container);
      final controller = await run(container);
      controller.setKeepBothLegs(0, true);
      expect(container.read(importFlowProvider).keepBothLegRows, {0});

      await controller.editRow(0, amountCents: 31000);

      final state = container.read(importFlowProvider);
      expect(state.hasMirrorMatch(0), isFalse);
      expect(state.keepBothLegRows, isEmpty);
    });
  });
}
