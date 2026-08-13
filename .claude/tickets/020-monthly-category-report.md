# Monthly report by category

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Analytics |
| **Domain** | Analytics |
| **Blocked By** | 006, 011, 012, 015 |
| **Status** | Ready |

## Description
Per-month breakdown of transactions grouped by **effective category**. Line-items with an override contribute to their own category (fractal rule from ticket 012); line-items without override roll up to their parent transaction's category; transactions without line-items use their own category. Uncategorized amounts surfaced as a separate block, not part of the donut composition.

Rendering: donut chart on top, sorted table beneath. Filters: month picker, account (default: all), Ausgaben ↔ Einnahmen toggle (auto-split by sign). Tap a table row → children view (recursive, tree-aware).

## Terms

- **Effective amount unit per category:** the smallest unit contributing to the report is either
  (a) a `Transaction` with `no line-items` — contributes its full `amountCents` to `effectiveCategoryUuid(transaction) = transaction.categoryUuid`, or
  (b) a `LineItem` (regular + restposten, non-deleted) — contributes its `amountCents` to `effectiveCategoryUuid(lineItem) = lineItem.categoryUuid ?? parentTransaction.categoryUuid`.
- **Rollup:** for each node in the category tree, its report value = sum of own effective amounts + sum of descendants' values.
- **Uncategorized:** any unit whose `effectiveCategoryUuid` is `null` goes into an "Uncategorized" bucket, rendered as a separate row / chip, **excluded** from the donut percentages.

## Filters

| Filter | Values | Default |
|--------|--------|---------|
| Month | `YYYY-MM` picker | current month |
| Account | `all` \| specific `accountUuid` | `all` (non-archived) |
| Direction | `Ausgaben` \| `Einnahmen` | `Ausgaben` (sign-based split) |

## Acceptance Criteria
- [ ] `fl_chart` dependency added
- [ ] `MonthlyCategoryReportService` in `lib/features/analytics/domain/monthly_category_report_service.dart`:
  - `Future<MonthlyCategoryReport> compute({required int year, required int month, String? accountUuid, required ReportDirection direction})`
  - Reads `TransactionRepository.findByAccount` (or all accounts when `accountUuid == null`) filtered by `bookingDate` in `[monthStart, monthEnd]` and `deleted == false`
  - For each transaction: if it has line-items → walk line-items (excluding `deleted`); otherwise → use transaction directly
  - Applies `effectiveCategoryUuid` from ticket 012's resolver — **shipped** at `lib/features/drilldown/domain/category_resolver.dart` (not the `features/category/` path 012 originally named, see decisions.md): `effectiveCategoryUuid(LineItem, Transaction)`, plus `resolveTransactionCategories(Transaction, List<LineItem>)` for a whole booking at once. Both are pure; filtering soft-deleted positions stays this service's job. Aggregating `LineItem.categoryUuid` directly instead of going through the resolver is the bug this note exists to prevent
  - Filters by direction: Ausgaben = `amountCents < 0`, Einnahmen = `amountCents > 0`, magnitudes shown as absolute values in the report
  - Rolls up into the category tree (uses `CategoryRepository`)
  - Returns `MonthlyCategoryReport { rows: List<CategoryRow>, uncategorizedCents: int, totalCents: int }`
- [ ] `CategoryRow` has: `categoryUuid`, `name`, `iconName`, `colorHex`, `ownCents`, `rollupCents`, `depth`, `parentCategoryUuid`
- [ ] `monthlyCategoryReportProvider` (Riverpod, family over filter object) exposes the report
- [ ] Report screen (`MonthlyCategoryReportScreen`):
  - Month picker (previous/next arrows + tap → picker)
  - Account chip (`Alle Konten` default) → single-select bottom sheet
  - Direction toggle (Ausgaben / Einnahmen)
  - Donut chart of top-level categories with `rollupCents` > 0
  - Table under chart: rows sorted by `rollupCents DESC`, first row = "Uncategorized" (when non-zero) shown separately (muted style)
  - Tap a category row → drills into a "children of X" view (same layout, filtered to that subtree)
- [ ] Empty state: "Keine Transaktionen für <Monat>" when no data
- [ ] Reactivity: report re-computes when any of {transaction, line-item, category, account} changes for that month
- [ ] All amounts displayed via `intl` NumberFormat.currency (`de_DE`, `EUR`)

## Affected Tests
- `test/features/analytics/domain/monthly_category_report_service_test.dart` — no data; only transactions no line-items; transactions with line-items overriding; uncategorized routing; direction split; account filter
- `test/features/analytics/domain/monthly_report_fractal_test.dart` — line-item override reflected correctly
- `test/features/analytics/presentation/monthly_report_screen_test.dart` — filters interact, drilldown works, empty state

## Fixtures Needed
No — inline builders.

## Refinement Tokens (estimate)
- Input: ~12k tokens
- Output: ~4k tokens

## Token Usage
_Filled after Done._
