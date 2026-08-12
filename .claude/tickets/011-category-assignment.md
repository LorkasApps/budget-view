# Category assignment on transaction

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Categories |
| **Domain** | Category |
| **Blocked By** | 010, 006 |
| **Status** | Done |

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
- [x] `categoryUuid` field added to `Transaction` entity (nullable String, indexed)
- [x] Manual-entry form (ticket 006): category picker added, validation blocks save when empty
- [x] PDF-import preview list (ticket 008): each row has an optional category picker; rows may stay empty
- [x] Import preview: "Für alle" batch action in the header — applies to every row, not just the selected ones
- [x] Transaction list row shows a category chip (icon + color + name from `Category`); shows `—` badge when `categoryUuid` is null
- [x] Transaction list: filter toggle "Nur ohne Kategorie"
- [x] Tapping the category chip on a list row opens quick-pick to (re)assign inline
- [x] Category picker is a tree-view (from ticket 010's tree) — user can pick leaf or node
- [x] Changing category on save enqueues an `update` op via `syncAdapter` — inherent to `TransactionRepository.save`, whose op selection is already covered by its own sync test
- [ ] Deleting a category is blocked while transactions reference it — **010 could not build this**: it ships `CategoryDeleteBlocked.transactionCount` wired into the user message but hardcoded to 0, because the field did not exist yet. Count non-deleted transactions for the uuid inside `CategoryRepository.delete`; the UI needs no change.

## Resolved before starting
`categoryUuid` stays nullable, **and ticket 010's `Category.parentUuid` was
retrofitted from its `''` sentinel to `String?`** so only one spelling of "not
set" exists. `kDbSchemaVersion` went to 2. No data migration was needed because
no app installation existed yet; on an installed app this would have required
either a wipe or a `'' → null` migration, since Isar keeps the same
`IsarType.string` for both and old rows would have kept their empty strings.

## Out of Scope
- Line-item-level category override (ticket 012 — fractal inheritance)
- Auto-suggest of category (tickets 013 + 014)
- Multi-select bulk-categorize on the transaction list (future ticket if pain shows up)

## Affected Tests
- `test/features/transaction/presentation/manual_entry_category_required_test.dart` — mandatory hint, save refused without a category, picking clears the hint, no clear-option offered for manual entry
- `test/features/transaction/import/domain/import_flow_controller_test.dart` — rows start and may stay uncategorized, `setRowCategory` vs `setCategoryForAll`, editing a row keeps its category, persist carries it onto the transaction
- `test/features/category/domain/category_repository_test.dart` — delete blocked by an active transaction, unblocked by a soft-deleted one, never blocked by an uncategorized one
- `test/features/category/domain/category_tree_test.dart` + `category_sync_integration_test.dart` — updated for the nullable parent

## Deviations from the original spec
| Spec | Built | Why |
|------|-------|-----|
| Per-row and inline pickers implied separate widgets | One `pickCategory` sheet reused by form, list quick-pick and import preview | Three call sites, one tree rendering. `allowNone` is the only difference between them |
| — | `CategoryPick` wrapper instead of returning `String?` | A raw `String?` cannot distinguish "dismissed the sheet" from "cleared the category" |
| — | `ImportRow.withCategory` alongside `copyWith` | `copyWith` cannot set a field back to null, so clearing a row's category would be inexpressible |

## Fixtures Needed
No — inline builders.

## Refinement Tokens (estimate)
- Input: ~8k tokens
- Output: ~2.5k tokens

## Implementation Tokens (estimate)
- Input: ~150k tokens
- Output: ~26k tokens
