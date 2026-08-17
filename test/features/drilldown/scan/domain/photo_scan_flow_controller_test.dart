import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/features/drilldown/domain/line_item_providers.dart';
import 'package:budget_view/features/drilldown/scan/domain/ocr_service.dart';
import 'package:budget_view/features/drilldown/scan/domain/photo_scan_flow_controller.dart';
import 'package:budget_view/features/drilldown/scan/domain/photo_scan_providers.dart';
import 'package:budget_view/features/drilldown/scan/domain/receipt_image_source.dart';
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

  test('startScan runs the happy path through to awaitingConfirm', () async {
    final container = containerWith(isar: isar);
    final transaction = await savedExpense(container);
    final controller = container.read(photoScanFlowProvider.notifier);
    expect(
      container.read(photoScanFlowProvider).phase,
      PhotoScanPhase.idle,
    );

    final phases = <PhotoScanPhase>[];
    container.listen(photoScanFlowProvider, (_, next) {
      phases.add(next.phase);
    });

    await controller.startScan(
      transaction: transaction,
      source: ScanSource.gallery,
    );

    expect(phases, [
      PhotoScanPhase.capturing,
      PhotoScanPhase.hashing,
      PhotoScanPhase.recognizing,
      PhotoScanPhase.parsing,
      PhotoScanPhase.awaitingConfirm,
    ]);
    final state = container.read(photoScanFlowProvider);
    expect(state.holdsImage, isTrue);
    expect(state.candidates.map((c) => c.description), ['Milch', 'Brot']);
  });

  test('the picker returning null lands the flow in cancelled', () async {
    final container = containerWith(
      isar: isar,
      imageSource: const CancellingReceiptImageSource(),
    );
    final transaction = await savedExpense(container);
    final controller = container.read(photoScanFlowProvider.notifier);

    await controller.startScan(
      transaction: transaction,
      source: ScanSource.camera,
    );

    final state = container.read(photoScanFlowProvider);
    expect(state.phase, PhotoScanPhase.cancelled);
    expect(state.holdsImage, isFalse);
  });

  test('holdsImage clears once confirm persists and drops the photo',
      () async {
    final container = containerWith(isar: isar);
    final transaction = await savedExpense(container);
    final controller = container.read(photoScanFlowProvider.notifier);

    await controller.startScan(
      transaction: transaction,
      source: ScanSource.gallery,
    );
    expect(container.read(photoScanFlowProvider).holdsImage, isTrue);

    await controller.confirm();

    final state = container.read(photoScanFlowProvider);
    expect(state.phase, PhotoScanPhase.done);
    expect(state.holdsImage, isFalse);
  });

  test('cancel drops the held image without persisting anything', () async {
    final container = containerWith(isar: isar);
    final transaction = await savedExpense(container);
    final controller = container.read(photoScanFlowProvider.notifier);

    await controller.startScan(
      transaction: transaction,
      source: ScanSource.gallery,
    );
    controller.cancel();

    final state = container.read(photoScanFlowProvider);
    expect(state.phase, PhotoScanPhase.cancelled);
    expect(state.holdsImage, isFalse);
    expect(state.candidates, isEmpty);

    final saved = await container
        .read(lineItemRepositoryProvider)
        .findByTransaction(transaction.uuid);
    expect(saved, isEmpty);
  });

  test('a failing OCR engine fails the scan and drops the held image',
      () async {
    final container = containerWith(
      isar: isar,
      ocr: ThrowingOcrService(
        OcrEngineException('Texterkennung fehlgeschlagen: boom'),
      ),
    );
    final transaction = await savedExpense(container);
    final controller = container.read(photoScanFlowProvider.notifier);

    await controller.startScan(
      transaction: transaction,
      source: ScanSource.gallery,
    );

    final state = container.read(photoScanFlowProvider);
    expect(state.phase, PhotoScanPhase.failed);
    expect(state.holdsImage, isFalse);
    expect(state.errorMessage, 'Texterkennung fehlgeschlagen: boom');
  });

  test('confirming against a booking that was never persisted fails',
      () async {
    final container = containerWith(isar: isar);
    // Built, deliberately not saved: the repository has no matching parent.
    final transaction = expenseTransaction();
    final controller = container.read(photoScanFlowProvider.notifier);

    await controller.startScan(
      transaction: transaction,
      source: ScanSource.gallery,
    );
    await controller.confirm();

    final state = container.read(photoScanFlowProvider);
    expect(state.phase, PhotoScanPhase.failed);
    expect(state.errorMessage, 'Buchung existiert nicht');
  });
}
