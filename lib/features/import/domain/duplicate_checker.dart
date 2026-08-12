import '../../transaction/data/transaction.dart';
import '../../transaction/domain/transaction_repository.dart';
import '../data/imported_source.dart';
import 'imported_source_repository.dart';

/// Two-layer duplicate suspicion. Neither layer ever blocks: both report, the
/// user decides.
///
/// An interface rather than a bare class, mirroring `SyncAdapter`, so widget
/// tests can stub it instead of dragging a database into the widget zone.
abstract interface class DuplicateChecker {
  /// Bookings on [accountUuid] whose dedupe hash matches. Account-scoped, so a
  /// transfer between two accounts is not flagged against itself.
  Future<List<Transaction>> findTransactionMatches(
    String dedupeHash, {
    required String accountUuid,
    bool excludeDeleted,
  });

  /// Previous imports of the same document, newest first. Global: the same file
  /// picked from anywhere should warn.
  Future<List<ImportedSource>> findDocumentMatches(String contentHash);
}

class LocalDuplicateChecker implements DuplicateChecker {
  const LocalDuplicateChecker(this._transactions, this._sources);

  final TransactionRepository _transactions;
  final ImportedSourceRepository _sources;

  @override
  Future<List<Transaction>> findTransactionMatches(
    String dedupeHash, {
    required String accountUuid,
    bool excludeDeleted = true,
  }) {
    return _transactions.findByDedupeHash(
      dedupeHash,
      accountUuid: accountUuid,
      includeDeleted: !excludeDeleted,
    );
  }

  @override
  Future<List<ImportedSource>> findDocumentMatches(String contentHash) =>
      _sources.findByHash(contentHash);
}
