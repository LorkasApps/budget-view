# Line-item entity (drilldown)

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | 006 |
| **Status** | In Progress |

## Description
Sub-transaction items enabling drilldown (Kassenbon items). One `Transaction` has N `LineItem`s. Line-items share the **sign of the parent transaction** (expense line-items are negative; refund line-items positive). Quantity + unit price are **optional** — OCR fills what it can, user edits freely. Sum validation + Restposten row belong to ticket 019. Fractal category inheritance belongs to ticket 012.

## Entity — `LineItem`

| Field | Type | Notes |
|-------|------|-------|
| `id` | int (auto-inc) | Isar internal |
| `uuid` | String | UUID v4 (from `SyncableEntity`) |
| `transactionUuid` | String | Indexed FK to `Transaction.uuid`. Required |
| `amountCents` | int64 | Signed. Same sign as parent transaction. Non-zero |
| `quantity` | double? | Nullable. Supports weight-based (`1.5`) and count-based |
| `unitPriceCents` | int64? | Nullable. Unsigned (magnitude). Derived if both `quantity` and `amountCents` known; separately editable |
| `description` | String | Non-empty (item name from OCR or manual entry) |
| `categoryUuid` | String? | Nullable. When null → inherits from parent transaction (ticket 012) |
| `kind` | enum | `regular` \| `restposten`. Default `regular`. `restposten` is created by ticket 019 |
| `orderIndex` | int | For stable UI ordering; default `createdAt`-based |
| `deleted` | bool | Default `false`. Soft-delete marker |
| `createdAt` | DateTime | |
| `updatedAt` | DateTime | |

**No unit / currency field** — same rules as `Transaction` (EUR, cents). Quantity's unit is free-form and lives in `description` for now (e.g. "H-Milch 1,5% 1L").

## Acceptance Criteria
- [ ] `LineItem` Isar collection in `lib/features/drilldown/data/line_item.dart`
- [ ] `LineItemRepository` in `lib/features/drilldown/domain/`: `save`, `softDelete(uuid)`, `findByTransaction(transactionUuid, {includeDeleted: false})`, `findByUuid`
- [ ] All writes route through `syncAdapter.enqueue(...)`
- [ ] `save` validates: `description` non-empty, `amountCents ≠ 0`, sign matches parent transaction's sign, `transactionUuid` points to existing transaction
- [ ] Optional derivation on save: if `quantity` and `unitPriceCents` both present, `amountCents` is checked against `quantity * unitPriceCents` with tolerance of 1 cent — mismatch is a warning, not a rejection (users may have discount rows)
- [ ] `lineItemRepositoryProvider` (Riverpod) exposes repo
- [ ] Transaction detail screen shows a "Line-items" section (empty state + add button)
- [ ] Line-item edit sheet: fields `description`, `amountCents` (EUR input), optional `quantity`, optional `unitPriceCents`, category picker (integrates ticket 012's "Inherit" option once 012 lands)
- [ ] Line-item list within transaction detail: draggable to reorder (writes `orderIndex`)
- [ ] Swipe / long-press → soft-delete
- [ ] Sum of non-deleted line-items shown as a live subtotal at the section footer (no validation here — 019 owns that)
- [ ] Deleting the parent transaction (soft) leaves line-items untouched at storage level; UI simply doesn't render them (they're only reachable through the transaction)

## Out of Scope
- Photo capture / OCR (tickets 016, 017, 018)
- Sum validation warnings + Restposten row (ticket 019)
- Fractal category inheritance UI + resolver (ticket 012)
- Analytics use of line-items (tickets 020, 022)

## Affected Tests
- `test/features/drilldown/domain/line_item_repository_test.dart` — save (validation: sign, non-empty, existing txn), softDelete, findByTransaction (deleted filter)
- `test/features/drilldown/domain/line_item_sync_integration_test.dart` — enqueue on writes
- `test/features/drilldown/presentation/line_item_edit_sheet_test.dart` — form validation, optional quantity/unit-price
- `test/features/drilldown/presentation/line_item_reorder_test.dart` — orderIndex persists

## Fixtures Needed
No — inline builders.

## Refinement Tokens (estimate)
- Input: ~10k tokens
- Output: ~3k tokens

## Token Usage
_Filled after Done._
