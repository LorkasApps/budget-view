import 'package:isar_community/isar.dart';

import '../../../core/sync/sync_adapter.dart';
import '../../../core/sync/sync_op.dart';
import '../../../core/sync/syncable_entity.dart';
import '../data/account.dart';

/// Persists [Account]s and mirrors every write to the sync change-queue,
/// per the repository-layer contract in docs/sync.md.
class AccountRepository {
  AccountRepository(this._isar, this._sync);

  final Isar _isar;
  final SyncAdapter _sync;

  Future<Account> save(Account account) async {
    final isNew = account.uuid.isEmpty;
    account.ensureUuid();
    final now = DateTime.now();
    if (isNew) {
      account.createdAt = now;
    }
    account.updatedAt = now;

    await _isar.writeTxn(() async {
      await _isar.accounts.put(account);
    });
    await _sync.enqueue(isNew ? SyncOp.create : SyncOp.update, account);
    return account;
  }

  /// Soft-delete: sets [Account.archived] and enqueues a delete op.
  Future<void> softDelete(String uuid) async {
    final account = await findByUuid(uuid);
    if (account == null || account.archived) return;
    account.archived = true;
    account.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.accounts.put(account);
    });
    await _sync.enqueue(SyncOp.delete, account);
  }

  /// Restore an archived account.
  Future<void> restore(String uuid) async {
    final account = await findByUuid(uuid);
    if (account == null || !account.archived) return;
    account.archived = false;
    account.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.accounts.put(account);
    });
    await _sync.enqueue(SyncOp.update, account);
  }

  Future<Account?> findByUuid(String uuid) =>
      _isar.accounts.filter().uuidEqualTo(uuid).findFirst();

  Future<List<Account>> findAll({bool includeArchived = false}) {
    if (includeArchived) {
      return _isar.accounts.where().sortByName().findAll();
    }
    return _isar.accounts
        .filter()
        .archivedEqualTo(false)
        .sortByName()
        .findAll();
  }
}
