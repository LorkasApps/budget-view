# Manual transaction entry

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Import |
| **Domain** | Transaction |
| **Blocked By** | 004, 005 |
| **Status** | Ready |

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
- [ ] `Transaction` Isar collection in `lib/features/transaction/data/transaction.dart`
- [ ] `TransactionRepository` in `lib/features/transaction/domain/`: `save(Transaction)`, `softDelete(uuid)`, `findByAccount(accountUuid, {includeDeleted: false})`, `findByUuid(uuid)`
- [ ] Every `save` / `softDelete` calls `syncAdapter.enqueue(...)`
- [ ] `uuid` auto-populated on first save; `createdAt` / `updatedAt` maintained
- [ ] `transactionRepositoryProvider` (Riverpod) exposes repo, overridable in tests
- [ ] Transaction form fields: signed `amount` (EUR input with sign toggle), `bookingDate` (date picker, default today), `description`, `account` (dropdown from active accounts), optional `counterparty`, optional `note`
- [ ] Form validation: `amount ≠ 0`, `description` non-empty, `bookingDate ≤ today`, `account` selected
- [ ] Transaction list screen (per account): sorted `bookingDate` DESC then `createdAt` DESC as tiebreaker
- [ ] Row layout: date (compact), description (primary), counterparty (secondary, small), formatted amount (sign color: green income / red expense)
- [ ] Swipe or long-press → soft-delete with confirmation
- [ ] Tap row → edit screen (same form, prefilled)
- [ ] **Extend `LocalBalanceService`:** `transactionSumCents` = sum(`amountCents`) where `accountUuid == X AND deleted == false`. Total = `openingBalanceCents + transactionSumCents`. Remove the `TODO(ticket-006)` marker.
- [ ] Balance stream on account list updates when a transaction is added / edited / soft-deleted

## Affected Tests
- `test/features/transaction/domain/transaction_repository_test.dart` — save, softDelete, findByAccount (includes/excludes deleted), findByUuid
- `test/features/transaction/domain/transaction_sync_integration_test.dart` — enqueue on save/softDelete
- `test/features/transaction/presentation/transaction_form_test.dart` — validation
- `test/features/account/data/local_balance_service_test.dart` — extended: opening + transaction sum, deleted excluded, archived account excluded

## Fixtures Needed
No — inline builders.

## Refinement Tokens (estimate)
- Input: ~10k tokens
- Output: ~3k tokens

## Token Usage
_Filled after Done._
