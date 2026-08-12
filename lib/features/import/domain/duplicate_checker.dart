import '../../transaction/data/transaction.dart';
import '../../transaction/domain/transaction_repository.dart';
import '../data/imported_source.dart';
import 'imported_source_repository.dart';

/// Two-layer duplicate suspicion. Neither layer ever blocks: both report, the
/// user decides.
class DuplicateChecker {
  const DuplicateChecker(this._transactions, this._sources);

  final TransactionRepository _transactions;
  final ImportedSourceRepository _sources;

  /// Bookings on the same account that hash identically. Account-scoped, so a
  /// transfer between accounts is not flagged against itself.
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

  /// Previous imports of the same document, newest first. Global: the same file
  /// picked from anywhere should warn.
  Future<List<ImportedSource>> findDocumentMatches(String contentHash) =>
      _sources.findByHash(contentHash);
}
