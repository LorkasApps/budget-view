# Item price trends

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Analytics |
| **Domain** | Analytics |
| **Blocked By** | 015, 018 |
| **Status** | Ready |

## Description
Track the price of individual items over time, sourced from `LineItem`s across all transactions. Items are grouped by **normalized description** — one distinct normalized string = one item group. Different sorts stay distinct (`h-milch 1,5% 1l` ≠ `h-milch 3,5% 1l`). OCR-induced spelling variants of the same product remain in separate groups; a future ticket may add an item-merge tool.

Only line-items are considered (not top-level transactions). Line-items from `kind == restposten` are excluded.

## Grouping + Normalization

Normalized key = `description.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ')`. Empty → excluded. Reuses the shared normalization helper (same as tickets 009 + 013).

## Price Metric per Data Point

Priority order:
1. If `unitPriceCents != null` → use `unitPriceCents` (magnitude)
2. Else if `quantity != null && quantity > 0 && amountCents != null` → `unitPriceCents = round(abs(amountCents) / quantity)`
3. Else if `amountCents != null` → use `abs(amountCents)` (treated as unit price, i.e. quantity=1 assumption)

Data-point date = parent transaction's `bookingDate`.

## Acceptance Criteria
- [ ] `ItemPriceTrendService` in `lib/features/analytics/domain/item_price_trend_service.dart`:
  - `Future<List<ItemGroup>> searchGroups(String query)` — substring match on normalized keys, returns groups with hit-count + latest price
  - `Future<ItemPriceSeries> series(String normalizedKey)` — returns `List<PricePoint> { date, unitPriceCents }` sorted by date ASC
- [ ] `itemPriceTrendServiceProvider` (Riverpod) exposes service
- [ ] Reuses shared normalization helper
- [ ] Item price trends screen:
  - Search bar (debounced)
  - Result list: item groups with `n Käufe`, latest price, chevron
  - Tap → chart screen for that item
- [ ] Chart screen (`fl_chart` LineChart):
  - x-axis = date, y-axis = unit price (EUR)
  - Dots for each purchase, connected by line
  - Marker for min / max price with label
  - Empty state: `Nur ein Datenpunkt (X,XX €) — kein Trend darstellbar` when N == 1
  - `Keine Käufe erfasst` when N == 0
- [ ] All prices formatted via `intl` NumberFormat.currency (`de_DE`, `EUR`)
- [ ] Reactivity: series re-computes when any line-item is added / edited / deleted

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

## Token Usage
_Filled after Done._
