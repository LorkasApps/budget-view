# Account entity + CRUD

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Accounts |
| **Domain** | Account |
| **Blocked By** | 002, 003 |
| **Status** | Done |

## Description
Multi-account support (Giro, Tagesgeld, zweites Tagesgeld, Sparkonto, ...). One user, N bank accounts. Soft-delete via `archived` flag preserves historical transactions. Repository writes route through `SyncAdapter` per architecture from 003.

## Entity

| Field | Type | Notes |
|-------|------|-------|
| `id` | int (auto-inc) | Internal Isar storage index |
| `uuid` | String | UUID v4, from `SyncableEntity`, business key |
| `name` | String | Non-empty, e.g. "Giro DKB" |
| `type` | enum | `giro` \| `tagesgeld` \| `sparkonto` \| `other` |
| `openingBalanceCents` | int64 | Signed. Negative allowed (e.g. Kredit). Cents to avoid float error |
| `openingDate` | DateTime | Anchor for balance calculation |
| `archived` | bool | Default `false`. Soft-delete marker |
| `createdAt` | DateTime | Set on first save |
| `updatedAt` | DateTime | Updated on every save |

Currency: EUR only for MVP — not stored as a field (see decisions.md).

## Acceptance Criteria
- [x] `Account` Isar collection defined in `lib/features/account/data/account.dart` (implements `SyncableEntity`)
- [x] `AccountRepository` with `save`, `softDelete(uuid)`, `restore(uuid)`, `findAll({includeArchived})`, `findByUuid`
- [x] Every `save` / `softDelete` / `restore` calls `syncAdapter.enqueue(...)` (create/delete/update)
- [x] `uuid` auto-populated on first save via `ensureUuid()`
- [x] `createdAt` set on insert; `updatedAt` set on every save
- [x] `accountRepositoryProvider` (Riverpod) exposes repo, overridable in tests
- [x] Create screen: form with `name`, `type` dropdown, `openingBalance` (EUR text input, comma/dot/negative), `openingDate` picker
- [x] Edit screen: same form, prefilled; all fields editable
- [x] List screen: non-archived accounts; swipe → soft-delete with confirmation dialog
- [x] "Show archived" toggle on list screen
- [x] Form validation: name non-empty; type always selected (dropdown default); opening date not in the future
- [x] Long-press on archived account → restore
- [x] Balance calculation NOT in scope (ticket 005) — tile shows opening balance only for now
- [x] App home wired to `AccountListScreen`; reactive list via `watchLazy` + repo `findAll`

## Affected Tests
- `test/features/account/domain/account_repository_test.dart` — save/softDelete/restore/findAll/findByUuid + sync enqueue ops (create/update/delete) — sync integration folded in here
- `test/features/account/domain/account_validation_test.dart` — name / openingBalance / openingDate validators (pure functions, extracted from the form)
- `test/widget_test.dart` — app boots to account list (empty state), real temp Isar

## Fixtures Needed
No — tests build accounts inline.

## Refinement Tokens (estimate)
- Input: ~10k tokens
- Output: ~2.5k tokens

## Implementation Tokens (estimate)
- Input: ~28k tokens
- Output: ~7k tokens
