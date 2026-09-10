# Item price trends

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Analytics |
| **Domain** | Analytics |
| **Blocked By** | 015, 018, 029 |
| **Status** | Done |

## Description
Track the price of individual items over time, sourced from `LineItem`s across all transactions. Items are grouped by **normalized description** — one distinct normalized string = one item group. Different sorts stay distinct (`h-milch 1,5% 1l` ≠ `h-milch 3,5% 1l`). OCR-induced spelling variants of the same product remain in separate groups; a future ticket may add an item-merge tool.

Only line-items are considered (not top-level transactions). Line-items from `kind == restposten` are excluded.

## Grouping + Normalization

Normalized key = `description.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')`. Reuses the shared normalization helper (same as tickets 009 + 013).

**Deviation (2026-08-19):** the planned "empty → excluded" guard was dropped. `LineItemRepository` validates the description as non-blank on every write, so no permitted write path can produce an empty key; see decisions.md.

## Price Metric per Data Point

Priority order:
1. If `unitPriceCents != null` → use `unitPriceCents` (magnitude)
2. Else if `quantity != null && quantity > 0 && amountCents != null` → `unitPriceCents = round(abs(amountCents) / quantity)`
3. Else `abs(amountCents)` (treated as unit price, i.e. quantity=1 assumption)

`LineItem.amountCents` is non-nullable and never 0, so branch 3 always applies and a position always yields a price — the nullable-amount branches this ticket sketched do not exist.

Data-point date = parent transaction's `bookingDate`.

## Entry point (settled by 029, 2026-08-18)
The screen is a **tile in `MenuScreen`**, not a fourth nav tab — a price search is
a rare surface, and the bar stays at three (decisions.md).

Second entry point (settled 2026-08-19): **long-press on a position row** in
`LineItemsSection` pushes that item's price history directly, skipping the search
for the case where the user is already looking at the item. Follows the long-press
deep-link precedent from 021 (report row → forecast).

## Acceptance Criteria
- [x] `ItemPriceTrendService` in `lib/features/analytics/domain/item_price_trend_service.dart`:
  - `Future<List<ItemGroup>> searchGroups(String query)` — substring match on normalized keys, returns groups with hit-count + latest price
  - `Future<ItemPriceSeries> series(String normalizedKey)` — returns `List<PricePoint> { date, unitPriceCents }` sorted by date ASC
- [x] `itemPriceTrendServiceProvider` (Riverpod) exposes service
- [x] Reuses shared normalization helper
- [x] Item price trends screen:
  - Search bar (debounced)
  - Result list: item groups with `n Käufe`, latest price, chevron
  - Tap → chart screen for that item
- [x] Entry points: `Preistrends` tile in `MenuScreen`; long-press on a position row
      in `LineItemsSection` → chart screen for that row's normalized description
      (Restposten row excluded — it is no item)
- [x] Chart screen (`fl_chart` LineChart):
  - x-axis = date, y-axis = unit price (EUR)
  - Dots for each purchase, connected by line
  - Marker for min / max price with label
  - Empty state: `Nur ein Datenpunkt (X,XX €) — kein Trend darstellbar` when N == 1
  - `Keine Käufe erfasst` when N == 0
- [x] All prices formatted via `intl` NumberFormat.currency (`de_DE`, `EUR`)
- [x] Reactivity: series re-computes when any line-item is added / edited / deleted

## Follow-up Note (not part of this ticket)
- Add a future ticket `TechDebt: Item-Merge Tool` — UI to select two normalized keys and merge them into one (updates line-item descriptions or introduces an `ItemAlias` table). Blocked by real-world OCR data showing duplication pain.

## Affected Tests
- `test/features/analytics/domain/item_price_trend_service_test.dart` — grouping, unit-price derivation (all three priority branches), restposten excluded
- `test/features/analytics/domain/item_price_trend_search_test.dart` — substring match, empty query returns empty, sorted by hit-count
- `test/features/analytics/presentation/item_price_trend_screen_test.dart` — search debounce, result list, empty states

## Fixtures Needed
No — inline builders.

## Refinement Tokens (estimate)
- Input: ~10k tokens
- Output: ~3k tokens

### Implementation Tokens (estimate)
- Input: ~185k tokens (incl. two sub-agents: tests ~130k, docs ~40k)
- Output: ~20k tokens
