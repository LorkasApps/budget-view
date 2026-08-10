# Account entity + CRUD

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Accounts |
| **Domain** | Account |
| **Blocked By** | 002, 003 |
| **Status** | Ready |

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
- [ ] `Account` Isar collection defined in `lib/features/account/data/account.dart`
- [ ] `AccountRepository` in `lib/features/account/domain/` with: `save(Account)`, `softDelete(uuid)`, `findAll({includeArchived: false})`, `findByUuid(uuid)`
- [ ] Every `save` and `softDelete` calls `syncAdapter.enqueue(...)` (per ticket 003 pattern)
- [ ] `uuid` auto-populated on first save (from `SyncableEntity` mixin)
- [ ] `createdAt` set on insert; `updatedAt` set on every save
- [ ] `accountRepositoryProvider` (Riverpod) exposes repo, overridable in tests
- [ ] Create screen: form with `name`, `type`, `openingBalance` (cents input UI: euro + cents fields or masked EUR input), `openingDate`
- [ ] Edit screen: same form, prefilled; all fields editable including opening balance/date
- [ ] List screen: shows non-archived accounts; long-press or swipe → soft-delete with confirmation
- [ ] "Show archived" toggle on list screen
- [ ] Form validation: name non-empty; type selected; opening date not in the future
- [ ] Long-press on archived account offers "restore" (sets `archived=false`)
- [ ] Balance calculation NOT in scope (ticket 005)

## Affected Tests
- `test/features/account/domain/account_repository_test.dart` — save/softDelete/findAll/findByUuid (in-memory Isar)
- `test/features/account/domain/account_sync_integration_test.dart` — save triggers `enqueue(create)`, softDelete triggers `enqueue(update)`
- `test/features/account/presentation/account_form_test.dart` — validation cases

## Fixtures Needed
No — tests build accounts inline.

## Refinement Tokens (estimate)
- Input: ~10k tokens
- Output: ~2.5k tokens

## Token Usage
_Filled after Done._
