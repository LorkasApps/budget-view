import 'package:isar_community/isar.dart';

import '../domain/account_balance.dart';
import '../domain/balance_service.dart';
import 'account.dart';

/// Local balance computation. Currently opening-balance only.
///
/// TODO(ticket-006): add the sum of active (non-deleted) transactions per
/// account — inject `TransactionRepository` and fill `transactionSumCents`.
class LocalBalanceService implements BalanceService {
  LocalBalanceService(this._isar);

  final Isar _isar;

  @override
  Stream<AccountBalance> watch(String accountUuid) async* {
    yield await _compute(accountUuid);
    await for (final _ in _isar.accounts.watchLazy()) {
      yield await _compute(accountUuid);
    }
  }

  Future<AccountBalance> _compute(String accountUuid) async {
    final account =
        await _isar.accounts.filter().uuidEqualTo(accountUuid).findFirst();
    return AccountBalance(
      accountUuid: accountUuid,
      openingBalanceCents: account?.openingBalanceCents ?? 0,
      transactionSumCents: 0,
    );
  }

  @override
  Stream<int> watchTotalCents({bool includeArchived = false}) async* {
    yield await _computeTotal(includeArchived);
    await for (final _ in _isar.accounts.watchLazy()) {
      yield await _computeTotal(includeArchived);
    }
  }

  Future<int> _computeTotal(bool includeArchived) async {
    final accounts = includeArchived
        ? await _isar.accounts.where().findAll()
        : await _isar.accounts.filter().archivedEqualTo(false).findAll();
    var total = 0;
    for (final account in accounts) {
      total += account.openingBalanceCents;
    }
    return total;
  }
}
