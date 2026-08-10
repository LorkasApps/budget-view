# Account balance display

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Accounts |
| **Domain** | Account |
| **Blocked By** | 004 |
| **Status** | Ready |

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
- [ ] `AccountBalance` value object defined
- [ ] `BalanceService` abstract interface defined in `lib/features/account/domain/balance_service.dart`
- [ ] `LocalBalanceService` concrete impl in `lib/features/account/data/local_balance_service.dart` — returns opening balance only, marked with `// TODO(ticket-006): sum transactions`
- [ ] `balanceServiceProvider` (Riverpod StreamProvider) exposes per-account balance stream, overridable in tests
- [ ] Account list row shows: `name`, `type` badge, formatted balance
- [ ] Balance formatted via `intl` package (`NumberFormat.currency`, locale `de_DE`, currency `EUR`)
- [ ] Negative balances rendered in a distinct color (theme-aware `error` color)
- [ ] List header shows sum of all non-archived account balances (total row)
- [ ] Balance updates reactively when Account's `openingBalance` is edited
- [ ] `intl` added as dependency
- [ ] Interface documented so ticket 006 can plug `TransactionRepository` in without touching UI

## Affected Tests
- `test/features/account/data/local_balance_service_test.dart` — opening-balance passthrough, watchTotalCents sums correctly, archived excluded
- `test/features/account/presentation/account_list_balance_test.dart` — currency formatting (positive, negative, zero), total-line calculation

## Fixtures Needed
No — inline account builders in tests.

## Refinement Tokens (estimate)
- Input: ~7k tokens
- Output: ~2k tokens

## Token Usage
_Filled after Done._
