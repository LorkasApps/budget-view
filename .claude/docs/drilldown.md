# Drilldown (Drilldown domain)

Positions of a booking (Kassenbon items). `lib/features/drilldown/`.

## Entity — `LineItem` (`data/line_item.dart`)
Implements `SyncableEntity` (`entityType = 'lineItem'`).

| Field | Type | Notes |
|-------|------|-------|
| `id` | Id | Isar auto-inc, internal |
| `uuid` | String | UUID v4, unique index |
| `transactionUuid` | String | Indexed FK to `Transaction.uuid` |
| `amountCents` | int | **Signed, same sign as the parent booking**; never 0 |
| `quantity` | double? | Count or weight; null = unknown |
| `unitPriceCents` | int? | Magnitude only; null = unknown |
| `description` | String | Non-empty, max 120 chars |
| `categoryUuid` | String? | Indexed; **null = inherit from the parent booking** (ticket 012 resolves it) |
| `kind` | `LineItemKind` | `regular` \| `restposten` (ticket 019 writes `restposten`); stored by name |
| `orderIndex` | int | Manual order, gaps of 1000; new rows get max+1000 |
| `deleted` | bool | Soft-delete marker |
| `createdAt` / `updatedAt` | DateTime | Maintained by repo |

No unit or currency field — EUR/cents like everywhere; the quantity's unit lives in `description`.

## Repository — `LineItemRepository` (`domain/line_item_repository.dart`)
| Method | Sync op |
|--------|---------|
| `save(item)` | create / update |
| `softDelete(uuid)` | delete (`deleted=true`) |
| `findByUuid(uuid)` | — |
| `findByTransaction(uuid, {includeDeleted})` | — sorted `orderIndex`, then `createdAt` |
| `reorder(ordered)` | update — rewrites `orderIndex` to `(i+1)*1000`, **only changed rows written** |
| `sumForTransaction(uuid)` | — sum of active `amountCents` |

Follows docs/sync.md contract. Takes `TransactionRepository` as its third constructor argument to resolve the parent booking on every `save` (narrow Drilldown → Transaction edge, see dependencies.md).

`save` rejects with **`LineItemInvalid`** (field `message`, German, user-facing): empty/too-long description, `amountCents == 0`, `quantity <= 0`, `unitPriceCents <= 0`, unknown `transactionUuid`, or a sign that differs from the parent booking's.

Parent soft-delete does **not** cascade: positions stay stored and are simply unreachable, because the only way in is the parent's form.

## Validation (`domain/line_item_validation.dart`)
Pure statics: `description`, `amount` (magnitude — unsigned, ≠ 0), `quantity`, `unitPrice`, plus:

- `amountMismatch({quantity, unitPriceCents, amountCents})` — warning text when `quantity × unitPrice` misses the amount by more than 1 cent, else null. **Warning only, never a rejection**: discount rows break the product on purpose. Lives in the sheet, not the repository.
- `quantityLabel(double)` — drops a trailing `.0`, decimal comma.

## Category resolution (`domain/category_resolver.dart`)
Fractal rule, pure, no repo access:

| Function | Returns |
|----------|---------|
| `effectiveCategoryUuid(LineItem, Transaction)` | position's own `categoryUuid`, else the parent booking's; null when both are null |
| `resolveTransactionCategories(Transaction, List<LineItem>)` | `Map<lineItemUuid, categoryUuid?>`; takes the list as given, caller filters soft-deleted rows |
| `inheritsCategory(LineItem)` | true while the position carries no own category |

**Integration point for analytics:** tickets 020 (monthly report) and 022 (item price trends) MUST resolve through `effectiveCategoryUuid` before aggregating line-items, so the rule cannot drift between call sites. A transaction without positions keeps its own category as the authoritative one.

Lives in Drilldown, not Category, although the rule is about categories: the functions take a `LineItem`, and `Category` depends only on Infra plus the narrow Transaction edge — see decisions.md.

## Providers (`domain/line_item_providers.dart`)
- `lineItemRepositoryProvider`
- `lineItemsProvider` (`StreamProvider.family<List<LineItem>, String>`) — per transaction uuid, re-queries on `isar.lineItems.watchLazy()`

## UI (`presentation/`)
**`LineItemsSection({transaction})`** — mounted inside `TransactionFormScreen` **in edit mode only** (a position needs its parent's uuid). Takes the whole parent entity because the badge and the inherit label both need its category. Header with title + live `Σ` subtotal, empty-state text, reorderable list, `+ Position` button.

Non-obvious details:
- `buildDefaultDragHandles: false` with an explicit `ReorderableDragStartListener`; the default handle would swallow the horizontal delete swipe.
- `shrinkWrap: true` + `NeverScrollableScrollPhysics` because the section sits inside the form's `ListView`.
- Swipe end-to-start → confirm dialog → `softDelete`.
- Each row's subtitle carries the category badge (and the quantity line after a `·`), not the trailing slot — a long category name next to amount and drag handle overflowed.
- Badge = effective category either way: dimmed to 55 % behind a `subdirectory_arrow_right` arrow when inherited, plain when the position overrides.

**`showLineItemSheet(context, {parent, existing})`** — bottom sheet, saves itself and pops. Fields: description, amount (magnitude — the sign comes from `parent`, so there is no expense/income toggle), optional quantity + price per unit side by side, category row (`allowNone: true`, `noneLabel` = "Erbt von der Buchung (<name>)", or "(ohne Kategorie)" while the booking itself has none). The mismatch warning renders inline under the two optional fields. `LineItemInvalid` from the repository surfaces as a snackbar.

The inherit label is built from a **watched** category list. Reading it during build froze the wording at the stream's loading state and rendered every booking as uncategorized; the tap handler reads instead, because watching outside build is not allowed.

## Not in scope here
- Photo capture / OCR (tickets 016–018)
- Sum validation + auto-managed Restposten row (ticket 019)
- Analytics over positions (tickets 020, 022)
