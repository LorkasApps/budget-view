# Category assignment on transaction

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Categories |
| **Domain** | Category |
| **Blocked By** | 010, 006 |
| **Status** | Ready |

## Description
Assign exactly one category (leaf or node) per transaction. The `categoryUuid` field on `Transaction` is nullable at the entity level; the constraint (required vs optional) is enforced at the **form / flow** level:

- **Manual entry:** category is **required** — form blocks save on empty.
- **PDF import:** category is **optional** — rows may be imported uncategorized; user categorizes later via the transaction list.

## Entity Change

Add to `Transaction`:

| Field | Type | Notes |
|-------|------|-------|
| `categoryUuid` | String? | Nullable. Indexed. FK to `Category.uuid`. |

## Acceptance Criteria
- [ ] `categoryUuid` field added to `Transaction` entity (nullable String, indexed)
- [ ] Manual-entry form (ticket 006): category picker added, validation blocks save when empty
- [ ] PDF-import preview list (ticket 008): each row has an optional category picker; rows may stay empty
- [ ] Import preview: "Set category for all rows" batch action available in header
- [ ] Transaction list row shows a category chip (icon + color + name from `Category`); shows `—` badge when `categoryUuid` is null
- [ ] Transaction list: filter toggle "Nur uncategorized"
- [ ] Tapping the category chip on a list row opens quick-pick to (re)assign inline
- [ ] Category picker is a tree-view (from ticket 010's tree) — user can pick leaf or node
- [ ] Changing category on save enqueues an `update` op via `syncAdapter`
- [ ] Deleting a category is blocked while transactions reference it — **010 could not build this**: it ships `CategoryDeleteBlocked.transactionCount` wired into the user message but hardcoded to 0, because the field did not exist yet. Count non-deleted transactions for the uuid inside `CategoryRepository.delete`; the UI needs no change.

## Decide before starting
`categoryUuid` is specified as a nullable `String?`. No stored field anywhere in
this schema is nullable — ticket 010 deliberately used `parentUuid = ''` as its
root sentinel for that reason. Either follow that convention (`''` =
uncategorized) or make `Transaction.categoryUuid` the first nullable stored
field and accept a nullable index. Pick one explicitly; do not let the two
conventions coexist.

## Out of Scope
- Line-item-level category override (ticket 012 — fractal inheritance)
- Auto-suggest of category (tickets 013 + 014)
- Multi-select bulk-categorize on the transaction list (future ticket if pain shows up)

## Affected Tests
- `test/features/transaction/domain/transaction_repository_test.dart` — save with + without categoryUuid
- `test/features/transaction/presentation/manual_entry_category_required_test.dart` — form blocks on empty
- `test/features/transaction/import/pdf/import_preview_category_optional_test.dart` — rows may stay empty; batch-set works
- `test/features/category/domain/category_repository_test.dart` — delete-block correctly detects the new `categoryUuid` field

## Fixtures Needed
No — inline builders.

## Refinement Tokens (estimate)
- Input: ~8k tokens
- Output: ~2.5k tokens

## Token Usage
_Filled after Done._
