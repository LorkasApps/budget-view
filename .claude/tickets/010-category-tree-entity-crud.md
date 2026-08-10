# Category tree entity + CRUD

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Categories |
| **Domain** | Category |
| **Blocked By** | 002, 003 |
| **Status** | Ready |

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
- [ ] `Category` Isar collection in `lib/features/category/data/category.dart`
- [ ] `CategoryRepository` in `lib/features/category/domain/`: `save`, `delete(uuid)`, `findAll({includeArchived: false})`, `findByUuid`, `findChildren(parentUuid)`, `findRoots()`
- [ ] Every write routes through `syncAdapter.enqueue(...)`
- [ ] `save` enforces: `name` non-empty; `(parentUuid, name)` unique among non-archived siblings; `parentUuid` (if set) points to existing category; no circular references (walk ancestors)
- [ ] `delete(uuid)` **blocks** with a domain error if:
  - The category has children (any archived state), OR
  - Any `Transaction` references it (checks `TransactionRepository`)
- [ ] Block error surfaces to UI with clear message + counts ("has 3 children, 12 transactions — move them first")
- [ ] `categoryRepositoryProvider` (Riverpod) exposes repo
- [ ] Category tree screen: expandable tree, drag-to-reorder within siblings, tap → edit sheet
- [ ] Create/Edit sheet: fields `name`, `parent` (picker), `icon` (picker over subset of Material Icons), `color` (picker over ~12 palette colors)
- [ ] Long-press → soft-delete (only if allowed, else show block message)
- [ ] "Show archived" toggle
- [ ] Restore action for archived nodes (`archived=false`)
- [ ] Sort within siblings by `sortOrder ASC`, tie-break by `name ASC`

## Out of Scope
- Assigning categories to transactions (ticket 011)
- Fractal inheritance for line-items (ticket 012)
- Import/export of category presets

## Affected Tests
- `test/features/category/domain/category_repository_test.dart` — save (validation, uniqueness, circular check), delete (block cases), findChildren, findRoots
- `test/features/category/domain/category_sync_integration_test.dart` — enqueue on writes
- `test/features/category/presentation/category_tree_test.dart` — expand/collapse, sort by sortOrder+name

## Fixtures Needed
No — inline builders in tests.

## Refinement Tokens (estimate)
- Input: ~9k tokens
- Output: ~3k tokens

## Token Usage
_Filled after Done._
