# Transaction (Transaction domain)

Manual bank-transaction entry. `lib/features/transaction/`.

## Entity — `Transaction` (`data/transaction.dart`)
Implements `SyncableEntity` (`entityType = 'transaction'`).

| Field | Type | Notes |
|-------|------|-------|
| `id` | Id | Isar auto-inc, internal |
| `uuid` | String | UUID v4, unique index |
| `accountUuid` | String | Indexed FK to `Account.uuid` |
| `amountCents` | int | **Signed**: negative = expense, positive = income |
| `bookingDate` | DateTime | Buchungstag |
| `description` | String | Required, non-empty |
| `counterparty` | String | May be empty |
| `note` | String | May be empty |
| `deleted` | bool | Soft-delete marker |
| `createdAt` / `updatedAt` | DateTime | Maintained by repo |

Not yet present: `valueDate`, `categoryUuid` (ticket 011), line-items (ticket 015), `dedupeHash` (ticket 009).

## Repository — `TransactionRepository` (`domain/`)
| Method | Sync op |
|--------|---------|
| `save(transaction)` | create / update |
| `softDelete(uuid)` | delete (`deleted=true`) |
| `findByUuid(uuid)` | — |
| `findByAccount(uuid, {includeDeleted})` | — sorted `bookingDate` DESC, `createdAt` DESC |
| `sumForAccount(uuid)` | — sum of non-deleted `amountCents` |

Follows the docs/sync.md contract.

## Providers (`domain/transaction_providers.dart`)
- `transactionRepositoryProvider`
- `transactionsProvider` (`StreamProvider.family<List<Transaction>, String>`) — per account, re-queries on `isar.transactions.watchLazy()`

## Validation (`domain/transaction_validation.dart`)
Pure statics: `description`, `amount` (magnitude — must be unsigned and ≠ 0), `bookingDate` (not future), `account`. The sign comes from the form's expense/income toggle, not the text field.

## UI (`presentation/`)
- `TransactionListScreen(account)` — saldo header (`Start … · Buchungen …`), newest-first list, swipe→delete (confirm), tap→edit, FAB→create, app-bar action edits the **account**.
- `TransactionFormScreen({existing, initialAccountUuid})` — `SegmentedButton` Ausgabe/Einnahme + magnitude amount, description, account dropdown, date picker, optional counterparty + note.

## Navigation
Account list row tap → `TransactionListScreen`. (Before ticket 006 it opened the account edit form; that moved into the transaction list's app bar.)

## Balance integration
`LocalBalanceService` (account domain) injects `TransactionRepository` and adds `sumForAccount` to the opening balance. Balance streams merge `accounts.watchLazy()` + `transactions.watchLazy()` via `StreamGroup` (`async` package).
