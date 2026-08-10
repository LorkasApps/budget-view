# Sum validation + auto-managed Restposten

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | 015 |
| **Status** | Ready |

## Description
Keep the sum of line-items invariant to the parent transaction's amount by **auto-managing** a single `kind=restposten` line-item per transaction. Whenever line-items change, a reconciler runs: it inserts, updates, or removes the Restposten row so that `sum(all line-items) == transaction.amountCents` within a 1-cent tolerance. Users may rename the Restposten row or override its category, but cannot manually create additional Restposten rows and cannot delete the auto-managed one.

## Rule

```
gap = transaction.amountCents - sum(lineItem.amountCents where kind == regular AND deleted == false)

if |gap| ≤ 1 cent AND restposten exists → remove restposten
if |gap| > 1 cent AND restposten exists → update restposten.amountCents = gap
if |gap| > 1 cent AND no restposten     → create restposten with amountCents = gap
if no regular line-items                 → remove restposten (nothing to reconcile)
```

Restposten `amountCents` shares sign with `gap`. If parent transaction is negative and line-items cover less than the full amount → gap is negative → Restposten is a further expense line. Same for positive parents.

## Restposten Row

| Field | Value |
|-------|-------|
| `kind` | `restposten` |
| `description` | User-editable. Default `"Restposten"` |
| `categoryUuid` | Default `null` (inherits parent via fractal rule from ticket 012) — user may override |
| `quantity` / `unitPriceCents` | Always `null` |
| `orderIndex` | Always at bottom (max sibling `orderIndex + 1`, kept there on updates) |

## Reconciler

```dart
abstract class RestpostenReconciler {
  /// Called after any line-item write for a given transaction.
  Future<void> reconcile(String transactionUuid);
}
```

Concrete `LocalRestpostenReconciler`:
- Reads current line-items via `LineItemRepository.findByTransaction`.
- Computes gap.
- Creates / updates / soft-deletes the Restposten row via `LineItemRepository`.
- Restposten writes route through `syncAdapter.enqueue(...)` like any other line-item write, but the entry carries the same `transactionUuid` so remote sync can co-locate.

Reconciler is invoked:
- After a manual save/delete of a line-item on the transaction detail screen
- After the scan-flow confirm step (016 + 018)
- After parent transaction's `amountCents` is edited (ticket 006 form)

## Acceptance Criteria
- [ ] `LineItem.kind` enum already exists (defined in ticket 015): confirm the `restposten` value is used and system-managed
- [ ] `LineItemRepository.save` **rejects** external saves where `kind == restposten` unless the caller is the reconciler (guarded via a service-internal method — e.g. `saveRestposten` accessible only from the reconciler class or a package-private constructor)
- [ ] `LineItemRepository.softDelete` **rejects** deletes on `restposten` rows from UI paths (repository throws `RestpostenNotManuallyModifiable`)
- [ ] `RestpostenReconciler` interface + `LocalRestpostenReconciler` concrete impl in `lib/features/drilldown/domain/`
- [ ] `restpostenReconcilerProvider` (Riverpod) exposes reconciler
- [ ] Every UI-driven line-item save/delete calls `reconciler.reconcile(transactionUuid)` after the write completes (single call, idempotent)
- [ ] Transaction detail screen: line-items section shows the Restposten row visually distinct (small badge `Restposten`, muted color); rename is editable inline, category picker functional
- [ ] Tolerance: `|gap| ≤ 1` cent means "match" — no Restposten created for rounding differences
- [ ] Editing the parent transaction's `amountCents` triggers reconcile for the transaction (via a hook in `TransactionRepository.save`)
- [ ] Editing a Restposten row's `description` / `categoryUuid` in UI: allowed. Editing its `amountCents` in UI: disabled (managed field)
- [ ] Live sum footer under the line-items section shows `total: X of Y` (X = sum of line-items, Y = transaction total). After reconciler runs, X == Y within tolerance
- [ ] If a user manually adjusts a regular line-item's amount so that sum > transaction total (over-shoot), gap becomes opposite-signed → Restposten with opposite sign of siblings is created (documented as valid state, e.g. transaction −50 but line-items totalling −55 → Restposten +5)

## Affected Tests
- `test/features/drilldown/domain/restposten_reconciler_test.dart` — all four branches of the rule + tolerance + sign handling
- `test/features/drilldown/domain/line_item_repository_restposten_guard_test.dart` — manual save/delete on restposten rejected
- `test/features/drilldown/presentation/line_item_section_restposten_ui_test.dart` — visual marker, editable description, locked amount
- `test/features/drilldown/scan/scan_confirm_reconcile_test.dart` — reconciler runs after scan-flow confirm

## Fixtures Needed
No — inline builders.

## Refinement Tokens (estimate)
- Input: ~11k tokens
- Output: ~4k tokens

## Token Usage
_Filled after Done._
