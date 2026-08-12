import 'package:isar_community/isar.dart';

import '../../../core/sync/sync_adapter.dart';
import '../../../core/sync/sync_op.dart';
import '../../../core/sync/syncable_entity.dart';
import '../data/imported_source.dart';

/// Persists import metadata, per the repository-layer contract in docs/sync.md.
class ImportedSourceRepository {
  ImportedSourceRepository(this._isar, this._sync);

  final Isar _isar;
  final SyncAdapter _sync;

  Future<ImportedSource> save(ImportedSource source) async {
    final isNew = source.uuid.isEmpty;
    source.ensureUuid();
    final now = DateTime.now();
    if (isNew) {
      source.createdAt = now;
    }
    source.updatedAt = now;

    await _isar.writeTxn(() async {
      await _isar.importedSources.put(source);
    });
    await _sync.enqueue(isNew ? SyncOp.create : SyncOp.update, source);
    return source;
  }

  /// Previous imports of the same document, newest first.
  Future<List<ImportedSource>> findByHash(String contentHashSha256) =>
      _isar.importedSources
          .filter()
          .contentHashSha256EqualTo(contentHashSha256)
          .sortByImportedAtDesc()
          .findAll();

  Future<List<ImportedSource>> findAll() =>
      _isar.importedSources.where().sortByImportedAtDesc().findAll();

  Future<ImportedSource?> findByUuid(String uuid) =>
      _isar.importedSources.filter().uuidEqualTo(uuid).findFirst();

  /// A real delete, not the soft-delete used elsewhere: this row exists to make
  /// a re-import warn, so an archived-but-still-warning row would be pointless.
  /// Removing it is the user's escape hatch for a legitimate re-import.
  Future<void> delete(String uuid) async {
    final source = await findByUuid(uuid);
    if (source == null) return;

    await _isar.writeTxn(() async {
      await _isar.importedSources.delete(source.id);
    });
    await _sync.enqueue(SyncOp.delete, source);
  }
}
