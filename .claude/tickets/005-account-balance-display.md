# Account balance display

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Accounts |
| **Domain** | Account |
| **Blocked By** | 004 |
| **Status** | Done |

## Description
Show per-account balance in the list. `BalanceService` interface defined so full logic (opening + sum of transactions) can slot in later. For now, concrete impl returns opening balance only — transaction aggregation joins in ticket 006 (or an explicit follow-up).

## Scope Boundary
- **In:** interface, provider, opening-balance-only impl, currency formatting, per-row + total display, reactive stream contract.
- **Out:** aggregation over transactions (waits for ticket 006), dashboard screen, account detail view.

## Architecture

```
BalanceService (interface)
  Stream<AccountBalance> watch(String accountUuid)
  Stream<int> watchTotalCents({includeArchived: false})

AccountBalance value object:
  { accountUuid, openingBalanceCents, transactionSumCents, totalCents }

LocalBalanceService (concrete, current impl)
  transactionSumCents = 0  // TODO: sum from TransactionRepository once ticket 006 lands
  totalCents = openingBalanceCents
```

## Acceptance Criteria
- [x] `AccountBalance` value object defined (`domain/account_balance.dart`, `totalCents = opening + transactionSum`)
- [x] `BalanceService` abstract interface defined in `lib/features/account/domain/balance_service.dart`
- [x] `LocalBalanceService` concrete impl in `lib/features/account/data/local_balance_service.dart` — opening only, `TODO(ticket-006)` marker
- [x] `balanceServiceProvider` + `accountBalanceProvider` (family) + `totalBalanceProvider` (family) exposed, overridable in tests
- [x] Account list row shows `name`, `type` subtitle, formatted balance (`_BalanceLabel`)
- [x] Balance formatted via `intl` (`NumberFormat.currency`, locale `de_DE`, symbol `€`) — `formatCentsEur`
- [x] Negative balances rendered in theme `error` color (row + total)
- [x] List header (`_TotalHeader`) shows sum of non-archived account balances
- [x] Balance updates reactively (service streams re-emit on `isar.accounts.watchLazy()`)
- [x] `intl` (^0.20.2) added as dependency
- [x] Interface documented so ticket 006 plugs the transaction sum in without touching UI

## Affected Tests
- `test/features/account/domain/local_balance_service_test.dart` — opening-balance passthrough, watchTotalCents sums, archived excluded, unknown-account → 0
- (Widget-level currency-formatting test deferred — formatting is covered by `formatCentsEur` and the service test; a dedicated widget test can be added when the balance UI grows in 006)

## Fixtures Needed
No — inline account builders in tests.

## Refinement Tokens (estimate)
- Input: ~7k tokens
- Output: ~2k tokens

## Implementation Tokens (estimate)
- Input: ~20k tokens
- Output: ~5k tokens
