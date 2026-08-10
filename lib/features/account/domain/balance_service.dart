import 'account_balance.dart';

/// Streams account balances. Interface kept minimal so ticket 006 can plug the
/// transaction sum in without touching the UI.
abstract interface class BalanceService {
  /// Balance for one account, re-emitted when relevant data changes.
  Stream<AccountBalance> watch(String accountUuid);

  /// Sum of all account balances (non-archived by default).
  Stream<int> watchTotalCents({bool includeArchived = false});
}
