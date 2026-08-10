import 'package:async/async.dart';
import 'package:isar_community/isar.dart';

import '../../transaction/data/transaction.dart';
import '../../transaction/domain/transaction_repository.dart';
import '../domain/account_balance.dart';
import '../domain/balance_service.dart';
import 'account.dart';

/// Local balance computation: opening balance plus the sum of active
/// transactions for the account. Re-emits whenever accounts or transactions
/// change.
class LocalBalanceService implements BalanceService {
  LocalBalanceService(this._isar, this._transactions);

  final Isar _isar;
  final TransactionRepository _transactions;

  /// Any change that can move a balance: account edits (opening balance,
  /// archived) or transaction writes.
  Stream<void> _changes() => StreamGroup.merge([
        _isar.accounts.watchLazy(),
        _isar.transactions.watchLazy(),
      ]);

  @override
  Stream<AccountBalance> watch(String accountUuid) async* {
    yield await _compute(accountUuid);
    await for (final _ in _changes()) {
      yield await _compute(accountUuid);
    }
  }

  Future<AccountBalance> _compute(String accountUuid) async {
    final account =
        await _isar.accounts.filter().uuidEqualTo(accountUuid).findFirst();
    return AccountBalance(
      accountUuid: accountUuid,
      openingBalanceCents: account?.openingBalanceCents ?? 0,
      transactionSumCents: await _transactions.sumForAccount(accountUuid),
    );
  }

  @override
  Stream<int> watchTotalCents({bool includeArchived = false}) async* {
    yield await _computeTotal(includeArchived);
    await for (final _ in _changes()) {
      yield await _computeTotal(includeArchived);
    }
  }

  Future<int> _computeTotal(bool includeArchived) async {
    final accounts = includeArchived
        ? await _isar.accounts.where().findAll()
        : await _isar.accounts.filter().archivedEqualTo(false).findAll();
    var total = 0;
    for (final account in accounts) {
      total += account.openingBalanceCents +
          await _transactions.sumForAccount(account.uuid);
    }
    return total;
  }
}
