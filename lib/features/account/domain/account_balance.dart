/// Computed balance for one account.
///
/// `total = opening + transactionSum`. In ticket 005 `transactionSumCents` is
/// always 0; ticket 006 fills it from active transactions.
class AccountBalance {
  const AccountBalance({
    required this.accountUuid,
    required this.openingBalanceCents,
    required this.transactionSumCents,
  });

  final String accountUuid;
  final int openingBalanceCents;
  final int transactionSumCents;

  int get totalCents => openingBalanceCents + transactionSumCents;
}
