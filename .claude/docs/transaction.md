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
| `kind` | `TransactionKind` | `regular` \| `transfer`; default `regular`. A transfer is money between user's own accounts: leaves one balance, arrives in another. Transfers need no category, exclude from reports. |
| `counterpartUuid` | String? | The other leg's `uuid` once a transfer named a target account (ticket 042). Null for everything else, including a transfer whose money left the app. No index — the value *is* the other row's unique-indexed `uuid`. Additive, so no `kDbSchemaVersion` bump |
| `bookingDate` | DateTime | Buchungstag |
| `description` | String | Required, non-empty |
| `counterparty` | String | May be empty |
| `merchant` | String | Who the money really went to when `counterparty` is a collective payer (PayPal, Adyen), read from the purpose text on import (ticket 047). Empty otherwise. Beside `counterparty`, never replacing it — that field is the booking's identity and feeds `dedupeHash`, which must not depend on a parser heuristic |
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

## Transfer pairs — `TransferPairService` (`domain/transfer_pair_service.dart`)

Owns both legs of a transfer. Called from the UI paths, never from
`TransactionRepository.save` (`decisions.md`, 2026-09-07).

| Method | Does |
|--------|------|
| `syncCounterpart(source, targetAccountUuid:)` | Called right after the form's save. Creates the counter-leg, or moves and mirrors an existing one, or takes it down when the target is null or the booking is no longer a transfer |
| `deletePair(transaction)` | Soft-deletes both legs. An unpaired booking takes the same path, so no call site has to decide which case it is in |
| `counterpartAccountOf(transaction)` | The account holding the other leg, so a confirmation can name it. Null when unpaired |

Rules the service enforces:

- Counter-leg: same amount **opposite sign**, same date, `kind = transfer`, no category, `counterparty` = the source account's name, description `Umbuchung von <Konto>` when it receives the money and `Umbuchung nach <Konto>` when it loses it
- **Moved, not rewritten** on a target change: `accountUuid` is updated and the uuid stays, so the change queue sees one `update` and user edits on that row survive
- The description is regenerated **only while it still equals either generated wording** — that is what lets a sign flip rewrite it while leaving the user's own text alone. `counterparty` and category belong to that leg once written
- Mirroring is a **form-edit rule**, not a `save` invariant: ticket 048 replaces a mirror leg with the bank's figures and must not propagate them
- Nothing pairs automatically. No target means no counter-leg, which is the legal 032 case — money moving to a broker outside the app is a real transfer with nothing to mirror

**Widget-test consequence:** the booking form reaches this service on every save, and the service composes `AccountRepository`, hence `isarProvider`. Any form widget test that drives a save to completion must override `transferPairServiceProvider` with a fake (`implements` works; no interface exists and none is needed).

## Providers (`domain/transaction_providers.dart`)
- `transactionRepositoryProvider`
- `transferPairServiceProvider` → `TransferPairService(transactionRepository, accountRepository)`
- `transactionsProvider` (`StreamProvider.family<List<Transaction>, String>`) — per account, re-queries on `isar.transactions.watchLazy()`

## Validation (`domain/transaction_validation.dart`)
Pure statics: `description`, `amount` (magnitude — must be unsigned and ≠ 0), `bookingDate` (not future), `account`, `category` (manual entry only; PDF import skips this check). The sign comes from the form's expense/income toggle, not the text field.

**Category check** (`category(String? categoryUuid, {TransactionKind kind})`): Returns `null` for a transfer (no category needed); for `regular` returns `'Kategorie erforderlich'` if missing.

## Form (`presentation/transaction_form_screen.dart`)

**Target account** (ticket 042) — with `Umbuchung` on, a second dropdown appears: `Gegenkonto (optional)`, first item `Kein Gegenkonto`, then every non-archived account **except** the source. Changing the source account to the chosen target drops the choice, since a pair inside one account cancels out on that balance. The choice survives toggling `Umbuchung` off and on, like a picked category (041); only the save acts on it. Editing an existing pair resolves the picker's initial value through `counterpartAccountOf`, because the link stores the other *booking* while the picker shows the other *account*.

**Transfer toggle** — `SwitchListTile` labelled `Umbuchung` under the Ausgabe/Einnahme toggle; subtitle says it counts in no report total and needs no category. The saved booking carries the chosen `kind`. With the switch **on**, the category row drops its required marker and its red `Pflichtfeld` text and its label reads `Kategorie (optional)` — the convention of every other optional field in this form. The suggestion marker is hidden too: the learn hook skips transfers, so accepting one would teach nothing. Toggling back restores both, and a category the user already picked survives either direction (ticket 041).

**Category suggestion**
- Counterparty field carries a `FocusNode`; **on blur** the form asks
  `taggingSuggestServiceProvider`. Not per keystroke: every lookup is an Isar query,
  and a half-typed counterparty matches nothing.
- The top hit fills the category only while the field is empty or still holds an
  untouched earlier suggestion; a hand-picked category is never overwritten.
- A counterparty that matches no rule gives a previously suggested category back up.
- While untouched, the `Kategorie` row's subtitle shows `Vorschlag · <hitCount>×` with
  an `Icons.auto_awesome_outlined` marker, plus an `Alternativen` button once more than
  one suggestion exists (opens `pickSuggestion`).
- `categoryAutoSuggested` is saved `true` only while that untouched suggestion stands.
  Both the category picker and picking an alternative count as overrides → `false`,
  which is what lets the learn hook raise the chosen rule.

**On save, before persistence:**
1. Compute `dedupeHash` for the form's values
2. Call `duplicateCheckerProvider.findTransactionMatches(hash, accountUuid:, excludeDeleted: true)`
3. Filter out the booking being edited (self-match when updating)
4. If matches remain, show modal: "Möglicher Doppel-Eintrag — Es gibt bereits [1 / N] Buchung[en] mit gleichem Betrag, Datum und Empfänger: [list]. **Trotzdem speichern** / **Abbrechen**"
5. If user confirms (or no matches), proceed to `TransactionRepository.save`

## UI (`presentation/`)
- `TransactionListScreen(account)` (`ConsumerStatefulWidget`) — saldo header (`Start … · Buchungen …`), filter row, newest-first list, swipe→delete (confirm; the dialog names the other account when the booking is one leg of a transfer, and deletion always runs through `TransferPairService.deletePair` — a widget test pins that `softDelete` is never called directly), tap→edit, FAB→create, app-bar actions: PDF import, edit account. Each row shows a `CategoryChip`; tap opens quick-pick to reassign inline, saves immediately. The row also shows `taggingKey` (`merchant` when one was read, else `counterparty`) — the row answers "who did I pay", and `PayPal Europe S.a.r.l.` is the useless answer (ticket 047).

**Filter row** (ticket 053) — search `TextField` (dense, `Icons.search`, hint `Suchen`, clear cross as in 038) plus an `InputChip` that opens `pickCategoryFilter`.

| Piece | Where | Rule |
|-------|-------|------|
| `TransactionFilter` | `domain/transaction_filter.dart` | Pure predicate over the streamed list, AND of search and category. `apply` returns the input unchanged while inactive |
| Search fields | — | `description`, `counterparty`, `merchant`, `note`, and **both** `formatCentsEur` (`1.234,56 €`) and `formatCentsPlain` (`1234,56`) of the amount — the grouping dot would otherwise swallow a typed `1234,56` |
| Search semantics | — | Case-insensitive substring, umlauts literal: `Bruehe` does not find `Brühe`. Not `normalizeForMatching` (ticket 038) |
| `CategoryFilter` | same file | `all` / `without` / `subtree`; subtree carries `rootUuid` plus the uuids from `subtreeUuids`, so a parent shows its children's bookings |
| `Ohne Kategorie` | — | Transfers drop out — they need no category, so they would dominate the list (ticket 049 closed here) |
| `pickCategoryFilter` | `presentation/category_filter_sheet.dart` | Own sheet, not `pickCategory`: that one carries quick-create, and all three states belong on screen as rows |
| Persistence | — | None. Pushed screen, so state ends with it |
| No match | — | `Keine Buchung passt zu Suche und Filter.` plus `Filter zurücksetzen` |

The balance header never reacts to the filter: it is a *balance* — opening balance plus every booking — not a list total, and a filtered figure would contradict the account list. Sums are the report's job (020, 052).
- `TransactionFormScreen({existing, initialAccountUuid})` — `SegmentedButton` Ausgabe/Einnahme + magnitude amount, description, **mandatory category row** (shows error "Kategorie erforderlich" in red if missing), account dropdown, date picker, optional counterparty + note.

## Import (`import/`)
PDF import preview displays `ImportRow` list. Each row has:
- Checkbox toggle (included in final persist or not)
- `CategoryChip` (per-row, optional — rows may be imported uncategorized)
- Edit button — full edit for description, amount, date, counterparty, **category and the `Umbuchung` switch**. Both of
  those live in the dialog only; the row itself has no transfer switch
- Header has a "Für alle" batch action (opens category picker, applies to all rows regardless of inclusion status)

`ImportRow.kind` field (default `regular`) travels into persisted `Transaction`. Per-row edit dialog uses `ImportFlowController.setRowKind(index, kind)` to update.

## Navigation
Account list row tap → `TransactionListScreen`. (Before ticket 006 it opened the account edit form; that moved into the transaction list's app bar.)

## Balance integration
`LocalBalanceService` (account domain) injects `TransactionRepository` and adds `sumForAccount` to the opening balance. Balance streams merge `accounts.watchLazy()` + `transactions.watchLazy()` via `StreamGroup` (`async` package).
