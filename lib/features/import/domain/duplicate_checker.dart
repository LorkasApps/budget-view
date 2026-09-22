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

  /// Mirror legs the app itself booked on [accountUuid] that this row could be
  /// the bank's own record of — same amount, booking date within [windowDays]
  /// (ticket 048).
  ///
  /// A third layer beside the hash, because the hash keys on the counterparty
  /// and the bank's text differs from the `Umbuchung von <Konto>` the app wrote.
  Future<List<Transaction>> findMirrorLegMatches({
    required String accountUuid,
    required int amountCents,
    required DateTime bookingDate,
    int windowDays,
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
  Future<List<Transaction>> findMirrorLegMatches({
    required String accountUuid,
    required int amountCents,
    required DateTime bookingDate,
    int windowDays = 5,
  }) {
    return _transactions.findTransferLegsNear(
      accountUuid: accountUuid,
      amountCents: amountCents,
      bookingDate: bookingDate,
      windowDays: windowDays,
    );
  }

  @override
  Future<List<ImportedSource>> findDocumentMatches(String contentHash) =>
      _sources.findByHash(contentHash);
}
