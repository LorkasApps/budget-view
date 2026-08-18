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
| `kind` | `LineItemKind` | `regular` \| `restposten`; stored by name. The `restposten` row is written **only** by the reconciler |
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
| `findByTransactions(uuids, {includeDeleted})` | — positions of many bookings in one `anyOf` query; analytics reads a whole month at once |
| `reorder(ordered)` | update — rewrites `orderIndex` to `(i+1)*1000`, **only changed rows written** |
| `sumForTransaction(uuid)` | — sum of active `amountCents` |
| `saveRestposten(item)` | create / update — **reconciler only** |
| `removeRestposten(uuid)` | delete — **reconciler only** |
| `updateRestpostenDetails(uuid, description:, categoryUuid:)` | update — the two fields a user owns on the managed row |
| `findRestposten(uuid)` | — active managed row of one booking, or null |

Follows docs/sync.md contract. Takes `TransactionRepository` as its third constructor argument to resolve the parent booking on every `save` (narrow Drilldown → Transaction edge, see dependencies.md).

`save` rejects with **`LineItemInvalid`** (field `message`, German, user-facing): empty/too-long description, `amountCents == 0`, `quantity <= 0`, `unitPriceCents <= 0`, unknown `transactionUuid`, or a sign that differs from the parent booking's.

Parent soft-delete does **not** cascade: positions stay stored and are simply unreachable, because the only way in is the parent's form.

## Validation (`domain/line_item_validation.dart`)
Pure statics: `description`, `amount` (magnitude — unsigned, ≠ 0), `quantity`, `unitPrice`, plus:

- `amountMismatch({quantity, unitPriceCents, amountCents})` — warning text when `quantity × unitPrice` misses the amount by more than 1 cent, else null. **Warning only, never a rejection**: discount rows break the product on purpose. Lives in the sheet, not the repository.
- `quantityLabel(double)` — drops a trailing `.0`, decimal comma.

## Restposten reconciler (`domain/restposten_reconciler.dart`)
`RestpostenReconciler` interface + `LocalRestpostenReconciler(lineItemRepo, transactionRepo)`, exposed as `restpostenReconcilerProvider`. Keeps at most one `kind = restposten` row per booking so the positions always add up to it.

```
gap = transaction.amountCents - sum(regular, non-deleted)
|gap| <= 1 cent           -> remove the managed row if present
|gap| >  1 cent           -> create or update it with amountCents = gap
no regular positions      -> remove it (nothing to reconcile)
```

`reconcile(transactionUuid)` is idempotent. The row's `quantity` / `unitPriceCents` stay null, its `orderIndex` is re-pinned to `max(regular) + 1000` on every run, and its sign follows the gap — **an overshoot legitimately opposes its siblings** (−50,00 booking with −55,00 in positions yields a +5,00 Restposten).

**Called from the UI, not from a repository hook** (see decisions.md): the sheet after a position save, the section after a delete and after a reorder, and `TransactionFormScreen` after the booking's own save. Ticket 018's scan-confirm step must call it too.

Guards: `save` and `softDelete` throw `RestpostenNotManuallyModifiable` for the managed kind; the reconciler uses `saveRestposten` / `removeRestposten`, which also skip the parent-sign rule. Dart has no package-private visibility, so this separation is enforced by a test rather than the compiler.

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
**`LineItemsSection({transaction})`** — mounted inside `TransactionFormScreen` **in edit mode only** (a position needs its parent's uuid). Takes the whole parent entity because the badge and the inherit label both need its category. Title, reorderable list, footer `Σ <sum> von <booking total>`, `+ Position` button.

Non-obvious details:
- `buildDefaultDragHandles: false` with an explicit `ReorderableDragStartListener`; the default handle would swallow the horizontal delete swipe.
- `shrinkWrap: true` + `NeverScrollableScrollPhysics` because the section sits inside the form's `ListView`.
- Swipe end-to-start → confirm dialog → `softDelete`.
- Each row's subtitle carries the category badge (and the quantity line after a `·`), not the trailing slot — a long category name next to amount and drag handle overflowed.
- Badge = effective category either way: dimmed to 55 % behind a `subdirectory_arrow_right` arrow when inherited, plain when the position overrides.
- The managed Restposten row carries a `Restposten` chip, muted text, **no drag handle and no swipe** — the repository would refuse the delete, and a row that animates away and returns reads as a bug. A reorder therefore writes only the regular rows and lets the reconciler re-pin the managed one.
- In the sheet the managed row keeps its amount visible but disabled (`Betrag (automatisch)`), hides quantity and unit price, and saves through `updateRestpostenDetails` — no reconcile needed, since neither field moves the sum.

**`showLineItemSheet(context, {parent, existing})`** — bottom sheet, saves itself and pops. Fields: description, amount (magnitude — the sign comes from `parent`, so there is no expense/income toggle), optional quantity + price per unit side by side, category row (`allowNone: true`, `noneLabel` = "Erbt von der Buchung (<name>)", or "(ohne Kategorie)" while the booking itself has none). The mismatch warning renders inline under the two optional fields. `LineItemInvalid` from the repository surfaces as a snackbar.

The inherit label is built from a **watched** category list. Reading it during build froze the wording at the stream's loading state and rendered every booking as uncategorized; the tap handler reads instead, because watching outside build is not allowed.

## Not in scope here
- Photo capture workflow: see `receipt-scan.md` (tickets 016, 017, 018 done)
- Analytics over positions (tickets 020, 022)
