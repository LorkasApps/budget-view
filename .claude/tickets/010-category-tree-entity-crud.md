# Category tree entity + CRUD

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Categories |
| **Domain** | Category |
| **Blocked By** | 002, 003 |
| **Status** | Done |

## Description
User-defined free category tree (parent-child, arbitrary depth). No hardcoded roots. Direction of a transaction (income/expense) is derived from `amountCents` sign, not from category placement. Delete blocked if a category has children or transactions — user moves them first. Names unique within the same parent.

## Entity

| Field | Type | Notes |
|-------|------|-------|
| `id` | int (auto-inc) | Internal Isar storage index |
| `uuid` | String | UUID v4, business key, from `SyncableEntity` |
| `name` | String | Non-empty. Unique within `parentUuid` |
| `parentUuid` | String? | `null` = root. Indexed |
| `sortOrder` | int | Manual sibling order, default `1000` (leave gaps for insert) |
| `iconName` | String | Material Icons name (e.g. `restaurant`, `car_rental`); default `label` |
| `colorHex` | String | 7-char hex incl. `#`; default from palette |
| `archived` | bool | Default `false` |
| `createdAt` | DateTime | |
| `updatedAt` | DateTime | |

## Acceptance Criteria
- [x] `Category` Isar collection in `lib/features/category/data/category.dart`
- [x] `CategoryRepository` in `lib/features/category/domain/`: `save`, `delete(uuid)`, `findAll({includeArchived: false})`, `findByUuid`, `findChildren(parentUuid)`, `findRoots()`, plus `restore` and `reorderSiblings`
- [x] Every write routes through `syncAdapter.enqueue(...)`
- [x] `save` enforces: `name` non-empty; `(parentUuid, name)` unique among non-archived siblings (case-insensitive); `parentUuid` (if set) points to existing category; no circular references (walk ancestors)
- [x] `delete(uuid)` **blocks** with a domain error if the category has children (any archived state)
- [x] Transaction-reference blocking **moved to ticket 011** — `Transaction` has no `categoryUuid` field, so the check cannot exist here. `CategoryDeleteBlocked.transactionCount` ships wired into the message, hardcoded to 0
- [x] Block error surfaces to UI with clear message + counts
- [x] `categoryRepositoryProvider` (Riverpod) exposes repo
- [x] Category tree screen: expandable tree, drag-to-reorder within siblings, tap → edit form
- [x] Create/Edit form: fields `name`, `parent` (picker excluding self + descendants), `icon` (24-icon curated set), `color` (12-colour palette)
- [x] Long-press → soft-delete (only if allowed, else show block message)
- [x] "Show archived" toggle
- [x] Restore action for archived nodes (`archived=false`)
- [x] Sort within siblings by `sortOrder ASC`, tie-break by `name ASC` (case-insensitive)

## Deviations from the original spec
| Spec | Built | Why |
|------|-------|-----|
| `parentUuid` as `String?`, `null` = root | `String parentUuid = ''`, empty = root | No stored field anywhere in this schema is nullable and there is no precedent for `@Index()` on a `String?`. The sentinel keeps root lookups a plain `parentUuidEqualTo('')` and avoids the one untested index path. |
| Edit **sheet** | Full-screen `CategoryFormScreen` | Matches the account and transaction forms, and the icon + colour grids need the room. |
| — | No `kDbSchemaVersion` bump | Adding a collection is additive; Isar opens existing databases unchanged. A bump would have falsely signalled that the dev DB needs nuking. |
| Delete blocks on transaction references | Children only | Forward dependency on ticket 011, see the open AC above. |

## Notes for ticket 011
`CategoryDeleteBlocked.transactionCount` is already part of the message. Once
`Transaction.categoryUuid` exists, count non-deleted transactions referencing the
uuid in `CategoryRepository.delete` and the AC closes without touching the UI.

## Out of Scope
- Assigning categories to transactions (ticket 011)
- Fractal inheritance for line-items (ticket 012)
- Import/export of category presets

## Affected Tests
- `test/features/category/domain/category_repository_test.dart` — save (validation, sibling uniqueness incl. case + archived freeing a name, missing/self parent, cycle), delete block + archive, restore, findRoots/findChildren ordering, reorderSiblings
- `test/features/category/domain/category_sync_integration_test.dart` — op sequence per write, and that rejected saves, blocked deletes and no-op reorders enqueue nothing
- `test/features/category/domain/category_tree_test.dart` — pure tree building, sibling ordering, orphan promotion, flattenVisible, ineligibleParents
- `test/features/category/presentation/category_tree_test.dart` — expand/collapse, ordering, empty state, archived row affordances (database-free per `.claude/docs/errors.md`)

## Fixtures Needed
No — inline builders in tests.

## Refinement Tokens (estimate)
- Input: ~9k tokens
- Output: ~3k tokens

## Implementation Tokens (estimate)
- Input: ~120k tokens
- Output: ~22k tokens
