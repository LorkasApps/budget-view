import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/features/drilldown/data/line_item.dart';
import 'package:budget_view/features/drilldown/domain/line_item_providers.dart';
import 'package:budget_view/features/drilldown/scan/domain/photo_scan_flow_controller.dart';
import 'package:budget_view/features/drilldown/scan/domain/photo_scan_providers.dart';
import 'package:budget_view/features/drilldown/scan/domain/receipt_image_source.dart';
import 'package:budget_view/features/drilldown/scan/domain/receipt_line_item_parser.dart';
import 'package:budget_view/features/import/domain/import_providers.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/domain/transaction_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'scan_test_support.dart';

void main() {
  late Directory tempDir;
  late Isar isar;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_scan_');
    isar = await openAppIsar(directory: tempDir.path);
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<Transaction> savedExpense(ProviderContainer container) =>
      container.read(transactionRepositoryProvider).save(expenseTransaction());

  test(
    '"Scan another" on the same booking adds a second row and positions',
    () async {
      final imageSource = FakeReceiptImageSource(
        CapturedReceiptImage(bytes: receiptBytes(1)),
      );
      final parser = FakeReceiptLineItemParser(defaultCandidates());
      final container = containerWith(
        isar: isar,
        imageSource: imageSource,
        parser: parser,
      );
      final transaction = await savedExpense(container);
      final controller = container.read(photoScanFlowProvider.notifier);

      await controller.startScan(
        transaction: transaction,
        source: ScanSource.gallery,
      );
      await controller.confirm();
      expect(container.read(photoScanFlowProvider).scansCompleted, 1);

      // Different bytes so the second pass gets its own content hash and
      // does not trip the duplicate warning against the first pass.
      imageSource.setNext(CapturedReceiptImage(bytes: receiptBytes(2)));
      parser.candidates = const [
        LineItemCandidate(description: 'Käse', amountCents: -299),
      ];

      await controller.startScan(
        transaction: transaction,
        source: ScanSource.gallery,
      );
      expect(
        container.read(photoScanFlowProvider).phase,
        PhotoScanPhase.awaitingConfirm,
      );
      await controller.confirm();

      final state = container.read(photoScanFlowProvider);
      expect(state.scansCompleted, 2);

      final items = await container
          .read(lineItemRepositoryProvider)
          .findByTransaction(transaction.uuid);
      final regular =
          items.where((i) => i.kind == LineItemKind.regular).toList();
      // 2 positions from the first pass, 1 from the second.
      expect(regular, hasLength(3));

      final repo = container.read(importedSourceRepositoryProvider);
      final sources = await repo.findAll();
      expect(sources, hasLength(2));
      expect(
        sources.map((s) => s.contentHashSha256).toSet(),
        hasLength(2),
      );
    },
  );
}
