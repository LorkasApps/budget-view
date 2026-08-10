# Manual transaction entry

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Import |
| **Domain** | Transaction |
| **Blocked By** | 004, 005 |
| **Status** | Done |

## Description
Manual entry of a bank transaction. Signed amount (negative = expense). Soft-delete preserves history. Repository writes route through `SyncAdapter`. Extends `LocalBalanceService` (from ticket 005) to include sum of active transactions per account — closes the TODO left there.

## Entity

| Field | Type | Notes |
|-------|------|-------|
| `id` | int (auto-inc) | Internal Isar storage index |
| `uuid` | String | UUID v4, business key |
| `accountUuid` | String (indexed) | FK to Account.uuid |
| `amountCents` | int64 | Signed. Negative = expense, positive = income |
| `bookingDate` | DateTime | Buchungstag |
| `description` | String | Required, non-empty |
| `counterparty` | String | Zahlungsempfänger / Absender. May be empty |
| `note` | String | Optional user note. May be empty |
| `deleted` | bool | Default `false`. Soft-delete marker |
| `createdAt` | DateTime | Set on insert |
| `updatedAt` | DateTime | Updated on every save |

`valueDate` (Wertstellung), category, drilldown line-items are handled in later tickets.

## Acceptance Criteria
- [x] `Transaction` Isar collection in `lib/features/transaction/data/transaction.dart` (implements `SyncableEntity`, `entityType='transaction'`)
- [x] `TransactionRepository`: `save`, `softDelete(uuid)`, `findByUuid`, `findByAccount(accountUuid, {includeDeleted})`, `sumForAccount(accountUuid)`
- [x] Every `save` / `softDelete` calls `syncAdapter.enqueue(...)` (create/update/delete)
- [x] `uuid` auto-populated on first save; `createdAt` / `updatedAt` maintained
- [x] `transactionRepositoryProvider` + `transactionsProvider` (family by accountUuid, reactive) exposed
- [x] Transaction form: expense/income `SegmentedButton` supplies the sign + magnitude amount field, `bookingDate` picker (default today), `description`, `account` dropdown (active accounts), optional `counterparty`, optional `note`
- [x] Form validation: magnitude ≠ 0 and unsigned, `description` non-empty, `bookingDate ≤ today`, `account` selected
- [x] Transaction list screen (per account): `bookingDate` DESC then `createdAt` DESC
- [x] Row layout: compact date leading, description title, counterparty subtitle (hidden when empty), amount trailing (red expense / green income)
- [x] Swipe → soft-delete with confirmation dialog
- [x] Tap row → edit screen (prefilled)
- [x] **`LocalBalanceService` extended:** `transactionSumCents = sumForAccount(uuid)` (non-deleted only); `TODO(ticket-006)` removed
- [x] Balance streams re-emit on account *and* transaction changes (`StreamGroup.merge` of both `watchLazy()`s; `async` dependency added)
- [x] Navigation: tapping an account row now opens its transaction list; account edit moved to the transaction list's app-bar action
- [x] Transaction list header shows account saldo with `Start … · Buchungen …` breakdown

## Affected Tests
- `test/features/transaction/domain/transaction_repository_test.dart` — save/softDelete/findByUuid/findByAccount (deleted filter, account filter, sort order), `sumForAccount`, plus sync-enqueue ops (integration folded in here)
- `test/features/transaction/domain/transaction_validation_test.dart` — description / amount (unsigned, ≠0) / bookingDate / account
- `test/features/account/domain/local_balance_service_test.dart` — extended: opening + transaction sum, deleted excluded, cross-account isolation, total with archived excluded/included

## Fixtures Needed
No — inline builders.

## Refinement Tokens (estimate)
- Input: ~10k tokens
- Output: ~3k tokens

## Implementation Tokens (estimate)
- Input: ~32k tokens
- Output: ~9k tokens
