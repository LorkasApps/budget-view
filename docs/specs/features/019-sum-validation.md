# Sum validation + auto-managed Restposten

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | 015 |
| **Status** | Done |

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
- [x] `LineItem.kind` enum already exists (defined in ticket 015): the `restposten` value is written only by the reconciler
- [x] `LineItemRepository.save` **rejects** external saves where `kind == restposten` — the reconciler's door is `saveRestposten`. **Not compiler-enforced**: Dart has no package-private visibility, privacy is library-wide. Moving the reconciler into the repository's file or passing a sentinel token would cost more readability than the guard is worth, so a test holds the line instead. See decisions.md
- [x] `LineItemRepository.softDelete` **rejects** deletes on `restposten` rows from UI paths (throws `RestpostenNotManuallyModifiable`); `removeRestposten` is the reconciler's door
- [x] `RestpostenReconciler` interface + `LocalRestpostenReconciler` concrete impl in `lib/features/drilldown/domain/`
- [x] `restpostenReconcilerProvider` (Riverpod) exposes reconciler
- [x] Every UI-driven line-item save/delete calls `reconciler.reconcile(transactionUuid)` after the write completes (single call, idempotent) — plus after a reorder, which re-pins the managed row to the bottom
- [x] Line-items section shows the Restposten row visually distinct (`Restposten` chip, muted text); rename and category picker work through the sheet. It is also excluded from drag and swipe rather than refusing them — a row that animates away and returns reads as a bug
- [x] Tolerance: `|gap| ≤ 1` cent means "match" — no Restposten created for rounding differences
- [x] Editing the parent transaction's `amountCents` triggers reconcile — **from `TransactionFormScreen`, not a hook in `TransactionRepository.save`**: the hook would have inverted the documented `Drilldown → Transaction` direction. See decisions.md
- [x] Editing a Restposten row's `description` / `categoryUuid` in UI: allowed via `updateRestpostenDetails`. Its `amountCents` is shown disabled (`Betrag (automatisch)`), quantity and unit price are hidden
- [x] Live sum footer under the line-items section — reads `Σ <sum> von <booking total>` (German UI, same content as the ticket's `total: X of Y`). Replaces the header `Σ` that ticket 015 had placed
- [x] Over-shoot produces an opposite-signed Restposten (−50 booking, −55 in positions → +5), tested; `saveRestposten` skips the parent-sign rule for exactly this case

## Affected Tests
- `test/features/drilldown/domain/restposten_reconciler_test.dart` — all four branches, tolerance, over-shoot sign, idempotency, soft-deleted rows excluded from the sum (9 tests)
- `test/features/drilldown/domain/line_item_repository_restposten_guard_test.dart` — manual save/delete rejected, both reconciler doors, `updateRestpostenDetails` touching only its two fields (7 tests)
- `test/features/drilldown/presentation/line_item_section_restposten_ui_test.dart` — badge, no drag handle, no `Dismissible`, footer, sheet title, disabled amount, hidden quantity fields (7 tests)
- ~~`test/features/drilldown/scan/scan_confirm_reconcile_test.dart`~~ — **dropped**: the scan flow does not exist yet (016–018 open). The requirement moved into ticket 018 as an AC, so it lands with the code it tests

Suite after the ticket: 226 passed, 0 failed, 2 skipped (was 203).

Not verified: never driven in an emulator (Flutter does not run in the agent sandbox).

## Fixtures Needed
No — inline builders.

## Refinement Tokens (estimate)
- Input: ~11k tokens
- Output: ~4k tokens

### Implementation Tokens (estimate)
- Input: ~145k tokens (~119k of it the delegated test pass on Sonnet)
- Output: ~15k tokens
