import 'package:isar_community/isar.dart';

import '../../../core/sync/sync_adapter.dart';
import '../../../core/sync/sync_op.dart';
import '../../../core/sync/syncable_entity.dart';
import '../data/transaction.dart';
import 'dedupe_hash.dart';

/// Persists [Transaction]s and mirrors every write to the sync change-queue,
/// per the repository-layer contract in docs/sync.md.
class TransactionRepository {
  TransactionRepository(this._isar, this._sync);

  final Isar _isar;
  final SyncAdapter _sync;

  Future<Transaction> save(Transaction transaction) async {
    final isNew = transaction.uuid.isEmpty;
    transaction.ensureUuid();
    final now = DateTime.now();
    if (isNew) {
      transaction.createdAt = now;
    }
    transaction.updatedAt = now;
    // Recomputed on every write, not just when empty: editing an amount, date
    // or counterparty would otherwise leave a hash describing the old booking.
    transaction.dedupeHash = computeDedupeHash(transaction);

    await _isar.writeTxn(() async {
      await _isar.transactions.put(transaction);
    });
    await _sync.enqueue(isNew ? SyncOp.create : SyncOp.update, transaction);
    return transaction;
  }

  Future<void> softDelete(String uuid) async {
    final transaction = await findByUuid(uuid);
    if (transaction == null || transaction.deleted) return;
    transaction.deleted = true;
    transaction.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.transactions.put(transaction);
    });
    await _sync.enqueue(SyncOp.delete, transaction);
  }

  Future<Transaction?> findByUuid(String uuid) =>
      _isar.transactions.filter().uuidEqualTo(uuid).findFirst();

  /// Newest first: `bookingDate` DESC, then `createdAt` DESC as tiebreaker.
  Future<List<Transaction>> findByAccount(
    String accountUuid, {
    bool includeDeleted = false,
  }) {
    if (includeDeleted) {
      return _isar.transactions
          .filter()
          .accountUuidEqualTo(accountUuid)
          .sortByBookingDateDesc()
          .thenByCreatedAtDesc()
          .findAll();
    }
    return _isar.transactions
        .filter()
        .accountUuidEqualTo(accountUuid)
        .deletedEqualTo(false)
        .sortByBookingDateDesc()
        .thenByCreatedAtDesc()
        .findAll();
  }

  /// Bookings with the same dedupe hash on one account. Scoped per account on
  /// purpose: a transfer between two accounts produces two legitimate bookings
  /// that hash identically.
  Future<List<Transaction>> findByDedupeHash(
    String dedupeHash, {
    required String accountUuid,
    bool includeDeleted = false,
  }) {
    if (includeDeleted) {
      return _isar.transactions
          .filter()
          .dedupeHashEqualTo(dedupeHash)
          .accountUuidEqualTo(accountUuid)
          .findAll();
    }
    return _isar.transactions
        .filter()
        .dedupeHashEqualTo(dedupeHash)
        .accountUuidEqualTo(accountUuid)
        .deletedEqualTo(false)
        .findAll();
  }

  /// Active transactions referencing one category. Backs the category
  /// delete-block, which refuses to archive a category still in use.
  Future<int> countByCategory(String categoryUuid) => _isar.transactions
      .filter()
      .categoryUuidEqualTo(categoryUuid)
      .deletedEqualTo(false)
      .count();

  /// Sum of active (non-deleted) transaction amounts for one account.
  Future<int> sumForAccount(String accountUuid) async {
    final transactions = await _isar.transactions
        .filter()
        .accountUuidEqualTo(accountUuid)
        .deletedEqualTo(false)
        .findAll();
    return transactions.fold<int>(0, (sum, t) => sum + t.amountCents);
  }
}
