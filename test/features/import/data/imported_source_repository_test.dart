import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/change_queue_entry.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/core/sync/sync_op.dart';
import 'package:budget_view/features/import/data/imported_source.dart';
import 'package:budget_view/features/import/data/imported_source_kind.dart';
import 'package:budget_view/features/import/domain/imported_source_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late ImportedSourceRepository repo;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_source_');
    isar = await openAppIsar(directory: tempDir.path);
    repo = ImportedSourceRepository(isar, LocalSyncAdapter(isar));
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<List<ChangeQueueEntry>> queue() =>
      isar.changeQueueEntrys.where().findAll();

  ImportedSource build({
    String hash = 'abc',
    String filename = 'auszug.pdf',
    ImportedSourceKind kind = ImportedSourceKind.pdf,
    DateTime? importedAt,
    int transactions = 3,
  }) {
    return ImportedSource()
      ..kind = kind
      ..contentHashSha256 = hash
      ..filename = filename
      ..importedAt = importedAt ?? DateTime(2026, 8, 1)
      ..transactionsProduced = transactions;
  }

  test('save assigns uuid + timestamps and enqueues a create', () async {
    final saved = await repo.save(build());

    expect(saved.uuid, isNotEmpty);
    expect(saved.createdAt, isNotNull);
    expect(saved.updatedAt, isNotNull);

    final entries = await queue();
    expect(entries.single.op, SyncOp.create);
    expect(entries.single.entityType, 'importedSource');
    expect(entries.single.entityUuid, saved.uuid);
  });

  test('the same hash may be recorded more than once', () async {
    await repo.save(build(importedAt: DateTime(2026, 7, 1)));
    await repo.save(build(importedAt: DateTime(2026, 8, 1)));

    final matches = await repo.findByHash('abc');

    expect(matches, hasLength(2));
    expect(matches.first.importedAt, DateTime(2026, 8, 1));
  });

  test('findByHash ignores other documents and unknown hashes', () async {
    await repo.save(build(hash: 'abc'));
    await repo.save(build(hash: 'def'));

    expect(await repo.findByHash('abc'), hasLength(1));
    expect(await repo.findByHash('nope'), isEmpty);
  });

  test('findAll returns every row, newest import first', () async {
    await repo.save(build(hash: 'a', importedAt: DateTime(2026, 6, 1)));
    await repo.save(build(hash: 'b', importedAt: DateTime(2026, 8, 1)));

    expect(
      (await repo.findAll()).map((row) => row.contentHashSha256),
      ['b', 'a'],
    );
  });

  test('delete removes the row for real and enqueues a delete', () async {
    final saved = await repo.save(build());

    await repo.delete(saved.uuid);

    expect(await repo.findAll(), isEmpty);
    expect(await repo.findByUuid(saved.uuid), isNull);
    expect((await queue()).map((entry) => entry.op), [
      SyncOp.create,
      SyncOp.delete,
    ]);
  });

  test('deleting an unknown uuid is a no-op', () async {
    await repo.delete('nope');

    expect(await queue(), isEmpty);
  });

  test('photo captures may carry an empty filename', () async {
    final saved = await repo.save(
      build(filename: '', kind: ImportedSourceKind.photo, transactions: 0)
        ..lineItemsProduced = 7,
    );

    expect(saved.filename, isEmpty);
    expect(saved.kind, ImportedSourceKind.photo);
    expect(saved.lineItemsProduced, 7);
  });
}
