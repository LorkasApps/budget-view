# Account (Account domain)

Multi-account management. Feature-first under `lib/features/account/`.

## Entity — `Account` (`data/account.dart`)
Implements `SyncableEntity` (`entityType = 'account'`).

| Field | Type | Notes |
|-------|------|-------|
| `id` | Id | Isar auto-inc, internal |
| `uuid` | String | UUID v4, unique index, business key |
| `name` | String | Non-empty |
| `type` | `AccountType` | `giro` / `tagesgeld` / `sparkonto` / `other` (`@enumerated`) |
| `openingBalanceCents` | int | Signed; negative allowed (Kredit) |
| `openingDate` | DateTime | Anchor for balance calc (ticket 005) |
| `archived` | bool | Soft-delete marker |
| `createdAt` / `updatedAt` | DateTime | Maintained by repo |

Currency: EUR only, not stored (decisions.md). Money = integer cents.

## Repository — `AccountRepository` (`domain/account_repository.dart`)
| Method | Sync op |
|--------|---------|
| `save(account)` | create (new uuid) / update |
| `softDelete(uuid)` | delete (sets `archived=true`) |
| `restore(uuid)` | update (sets `archived=false`) |
| `findByUuid(uuid)` | — |
| `findAll({includeArchived})` | — (sorted by name) |

Follows the docs/sync.md contract: `ensureUuid()` → Isar write → `syncAdapter.enqueue`.

## Balance (tickets 005 + 006)
- `AccountBalance` (`domain/account_balance.dart`): `{accountUuid, openingBalanceCents, transactionSumCents}`, `totalCents = opening + transactionSum`.
- `BalanceService` (`domain/balance_service.dart`): `watch(uuid) → Stream<AccountBalance>`, `watchTotalCents({includeArchived}) → Stream<int>`.
- `LocalBalanceService` (`data/local_balance_service.dart`): opening balance + `TransactionRepository.sumForAccount` (non-deleted only). Streams re-emit on a `StreamGroup.merge` of `accounts.watchLazy()` + `transactions.watchLazy()`.

## Providers (`domain/account_providers.dart`)
- `accountRepositoryProvider` → `AccountRepository(isar, syncAdapter)`
- `accountsProvider` (`StreamProvider.family<List<Account>, bool>`) — reactive list; param = includeArchived. Emits initial snapshot then re-queries on `isar.accounts.watchLazy()`.
- `balanceServiceProvider` → `LocalBalanceService(isar)`
- `accountBalanceProvider` (`StreamProvider.family<AccountBalance, String>`) — per-account balance
- `totalBalanceProvider` (`StreamProvider.family<int, bool>`) — total across accounts

## Validation (`domain/account_validation.dart`)
Pure static validators: `name`, `openingBalance` (parseable cents), `openingDate` (not future). Unit-tested independently of the widget.

## UI (`presentation/`)
- `AccountListScreen` — reactive list, archived toggle, swipe→archive (confirm dialog), long-press archived→restore, FAB→create. App home. **Row tap → `TransactionListScreen`** (since ticket 006); account edit lives in that screen's app bar.
- `AccountFormScreen` — create/edit; name, type dropdown, EUR balance input, date picker.

## UI additions (ticket 005)
- `_TotalHeader` — sum row atop the account list (reads `totalBalanceProvider`)
- `_BalanceLabel` — per-row balance (reads `accountBalanceProvider`); negative → theme `error` color

## Money helpers (`lib/core/money/money.dart`)
`parseEurosToCents` (comma/dot/negative), `formatCentsPlain` (no symbol, form input), `formatCentsEur` (intl `NumberFormat.currency`, `de_DE`/`€`, used for display).

## Not in scope here
- Category assignment on transactions (ticket 011)
