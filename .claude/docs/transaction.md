# Transaction (Transaction domain)

Manual bank-transaction entry. `lib/features/transaction/`.

## Entity — `Transaction` (`data/transaction.dart`)
Implements `SyncableEntity` (`entityType = 'transaction'`).

| Field | Type | Notes |
|-------|------|-------|
| `id` | Id | Isar auto-inc, internal |
| `uuid` | String | UUID v4, unique index |
| `accountUuid` | String | Indexed FK to `Account.uuid` |
| `categoryUuid` | String? | Indexed FK to `Category.uuid`; null while uncategorized. Required by manual-entry form, optional in PDF import. |
| `amountCents` | int | **Signed**: negative = expense, positive = income |
| `bookingDate` | DateTime | Buchungstag |
| `description` | String | Required, non-empty |
| `counterparty` | String | May be empty |
| `note` | String | May be empty |
| `dedupeHash` | String | Indexed, non-nullable. SHA-256 over amount + booking day + normalized counterparty; computed on every write by the repository |
| `deleted` | bool | Soft-delete marker |
| `createdAt` / `updatedAt` | DateTime | Maintained by repo |

Not yet present: `valueDate`, line-items (ticket 015).

## Repository — `TransactionRepository` (`domain/`)
| Method | Sync op |
|--------|---------|
| `save(transaction)` | create / update; **recomputes `dedupeHash` on every write** so editing amount, date or counterparty cannot leave a stale hash |
| `softDelete(uuid)` | delete (`deleted=true`) |
| `findByUuid(uuid)` | — |
| `findByAccount(uuid, {includeDeleted})` | — sorted `bookingDate` DESC, `createdAt` DESC |
| `findByDedupeHash(hash, accountUuid:, includeDeleted:)` | — account-scoped; bookings with matching dedupe hash (transfers between accounts stay distinct) |
| `countByCategory(categoryUuid)` | — counts non-deleted transactions; backs category delete-block |
| `sumForAccount(uuid)` | — sum of non-deleted `amountCents` |

Follows the docs/sync.md contract.

## Dedupe Hash (`domain/dedupe_hash.dart`)

Two entry points:

- `computeDedupeHash(Transaction)` — given a persisted or partially-filled transaction
- `dedupeHashOf(amountCents:, bookingDate:, counterparty:)` — field-level, for import preview rows not yet entities

**Hash Formula:** SHA-256 over `${amountCents}|YYYY-MM-DD|normalized_counterparty`:
- Amount: signed integer as-is
- Date: `YYYY-MM-DD` format, day only (same booking by hand and from statement must hash equal even if time differs)
- Counterparty: normalized via `normalizeForMatching` (lower, trim, collapse whitespace)
- Empty counterparty stays empty; collision is **deliberate** — warns but never auto-rejects

Normalization lives in `lib/core/text/normalize.dart` because tagging (ticket 013) must normalize identically.

## Providers (`domain/transaction_providers.dart`)
- `transactionRepositoryProvider`
- `transactionsProvider` (`StreamProvider.family<List<Transaction>, String>`) — per account, re-queries on `isar.transactions.watchLazy()`

## Validation (`domain/transaction_validation.dart`)
Pure statics: `description`, `amount` (magnitude — must be unsigned and ≠ 0), `bookingDate` (not future), `account`, `category` (manual entry only; PDF import skips this check). The sign comes from the form's expense/income toggle, not the text field.

## Form (`presentation/transaction_form_screen.dart`)

On save, before persistence:
1. Compute `dedupeHash` for the form's values
2. Call `duplicateCheckerProvider.findTransactionMatches(hash, accountUuid:, excludeDeleted: true)`
3. Filter out the booking being edited (self-match when updating)
4. If matches remain, show modal: "Möglicher Doppel-Eintrag — Es gibt bereits [1 / N] Buchung[en] mit gleichem Betrag, Datum und Empfänger: [list]. **Trotzdem speichern** / **Abbrechen**"
5. If user confirms (or no matches), proceed to `TransactionRepository.save`

## UI (`presentation/`)
- `TransactionListScreen(account)` (`ConsumerStatefulWidget`) — saldo header (`Start … · Buchungen …`), newest-first list, swipe→delete (confirm), tap→edit, FAB→create, app-bar actions: filter toggle (uncategorized-only), edit account. Each row shows a `CategoryChip`; tap opens quick-pick to reassign inline, saves immediately.
- `TransactionFormScreen({existing, initialAccountUuid})` — `SegmentedButton` Ausgabe/Einnahme + magnitude amount, description, **mandatory category row** (shows error "Kategorie erforderlich" in red if missing), account dropdown, date picker, optional counterparty + note.

## Import (`import/`)
PDF import preview displays `ImportRow` list. Each row has:
- Checkbox toggle (included in final persist or not)
- `CategoryChip` (per-row, optional — rows may be imported uncategorized)
- Edit button (opens full edit for description, amount, date, counterparty)
- Header has a "Für alle" batch action (opens category picker, applies to all rows regardless of inclusion status)

Final persist reads `ImportRow.categoryUuid` and assigns to each transaction.

## Navigation
Account list row tap → `TransactionListScreen`. (Before ticket 006 it opened the account edit form; that moved into the transaction list's app bar.)

## Balance integration
`LocalBalanceService` (account domain) injects `TransactionRepository` and adds `sumForAccount` to the opening balance. Balance streams merge `accounts.watchLazy()` + `transactions.watchLazy()` via `StreamGroup` (`async` package).
