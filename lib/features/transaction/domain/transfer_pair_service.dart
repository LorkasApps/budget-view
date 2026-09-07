import '../../account/data/account.dart';
import '../../account/domain/account_repository.dart';
import '../data/transaction.dart';
import 'transaction_repository.dart';

/// Owns the two legs of a transfer: writing the counter-leg on the named target
/// account, keeping amount and date in step, moving it when the target changes,
/// and taking both legs down together.
///
/// Deliberately not folded into `TransactionRepository.save`, even though both
/// legs are Transactions and no dependency edge would be inverted by it:
///
/// - **Mirroring has to stay a form-edit rule.** Ticket 048 replaces a mirror
///   leg with the bank's own figures and must *not* propagate them: money can
///   leave on one day and arrive on another, and a fee can make the two amounts
///   differ legitimately. An unconditional `save` invariant walls that off.
/// - **The cascading delete needs a confirmation naming the other account**,
///   and a repository cannot show a dialog. A silent cascade underneath a UI
///   that is still asking would be two answers to one question.
///
/// The accepted risk is the one `decisions.md` already named on 2026-08-13 for
/// the line-item reconcile: a future write path can forget to call this. The
/// answer is the same one — a guard plus a test pinning the call sites, not a
/// compiler.
class TransferPairService {
  TransferPairService(this._transactions, this._accounts);

  final TransactionRepository _transactions;
  final AccountRepository _accounts;

  /// Reconciles [source]'s counter-leg with [targetAccountUuid]. Call it after
  /// saving [source].
  ///
  /// No target — or a booking that is no longer a transfer at all — takes the
  /// counter-leg down and drops the link. An existing counter-leg is moved and
  /// mirrored rather than rewritten, so its uuid stays stable and anything the
  /// user already edited on that row survives.
  ///
  /// Works from either side: editing the leg the user happens to be looking at
  /// mirrors onto the other one, whichever that is.
  Future<void> syncCounterpart(
    Transaction source, {
    required String? targetAccountUuid,
  }) async {
    final existing = await _counterpartOf(source);
    final wanted = source.kind == TransactionKind.transfer
        ? targetAccountUuid
        : null;

    if (wanted == null) {
      if (existing != null) await _transactions.softDelete(existing.uuid);
      if (source.counterpartUuid != null) {
        source.counterpartUuid = null;
        await _transactions.save(source);
      }
      return;
    }

    final sourceAccount = await _accounts.findByUuid(source.accountUuid);
    final sourceName = sourceAccount?.name ?? '';

    if (existing == null) {
      final counter = Transaction()
        ..accountUuid = wanted
        ..amountCents = -source.amountCents
        ..bookingDate = source.bookingDate
        ..kind = TransactionKind.transfer
        ..description = _describe(sourceName, source.amountCents)
        ..counterparty = sourceName
        ..counterpartUuid = source.uuid;
      final saved = await _transactions.save(counter);

      source.counterpartUuid = saved.uuid;
      await _transactions.save(source);
      return;
    }

    // Read before mutating: whether the description is still the generated one
    // decides if it may be rewritten.
    final generated = _isGenerated(existing.description, sourceName);

    // Moved, not rewritten: one `update` in the change queue instead of a
    // delete plus a create. `counterparty` is left alone — it belongs to that
    // leg once written, like its category.
    existing
      ..accountUuid = wanted
      ..amountCents = -source.amountCents
      ..bookingDate = source.bookingDate
      ..kind = TransactionKind.transfer
      ..counterpartUuid = source.uuid;
    if (generated) {
      existing.description = _describe(sourceName, source.amountCents);
    }
    await _transactions.save(existing);
  }

  /// Soft-deletes [transaction] and the other leg with it.
  ///
  /// Deviates from the non-cascade of line items (`decisions.md`, 2026-08-13):
  /// a line item is only reachable through its booking, while both legs here
  /// are reachable through their own account, so a leftover leg stays visible —
  /// and wrong in that account's balance.
  Future<void> deletePair(Transaction transaction) async {
    final other = await _counterpartOf(transaction);
    if (other != null) await _transactions.softDelete(other.uuid);
    await _transactions.softDelete(transaction.uuid);
  }

  /// The account holding the other leg, so a confirmation can name it. Null
  /// when [transaction] is unpaired.
  Future<Account?> counterpartAccountOf(Transaction transaction) async {
    final other = await _counterpartOf(transaction);
    if (other == null) return null;
    return _accounts.findByUuid(other.accountUuid);
  }

  Future<Transaction?> _counterpartOf(Transaction transaction) async {
    final uuid = transaction.counterpartUuid;
    if (uuid == null) return null;
    return _transactions.findByUuid(uuid);
  }

  /// `Umbuchung von X` on the leg receiving the money, `Umbuchung nach X` on
  /// the one it leaves. Not an invention but the single fact that row carries:
  /// it exists because something happened on the other account. Copying the
  /// source description was rejected — `Miete` on the other side of a
  /// Tagesgeld transfer does not describe what happened there.
  static String _describe(String otherAccountName, int sourceCents) {
    return sourceCents < 0
        ? 'Umbuchung von $otherAccountName'
        : 'Umbuchung nach $otherAccountName';
  }

  /// True while the row still carries either generated wording, in which case a
  /// sign flip may rewrite it. Anything else is the user's text and stays.
  static bool _isGenerated(String description, String otherAccountName) {
    return description == 'Umbuchung von $otherAccountName' ||
        description == 'Umbuchung nach $otherAccountName';
  }
}
