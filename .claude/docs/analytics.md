# Analytics (Analytics domain)

Positions/bookings of a month aggregated into the category tree. `lib/features/analytics/`.

## Model — `domain/monthly_category_report.dart`
`enum ReportDirection { expenses, income }` — split follows the sign of the booking, never the category's placement.

**`MonthlyReportFilter`** — value-equal (it is the provider family key).

| Field | Type | Notes |
|-------|------|-------|
| `year` / `month` | int | |
| `accountUuid` | String? | `null` = all non-archived accounts |
| `direction` | `ReportDirection` | default `expenses` |

Named ctor `.of(DateTime)`, getter `monthStart`, and copies `shiftMonths(int)`, `withMonth(DateTime)`, `withAccount(String?)`, `withDirection(ReportDirection)`.

**`CategoryRow`** — `categoryUuid`, `name`, `iconName`, `colorHex`, `ownCents`, `rollupCents`, `depth`, `parentCategoryUuid`. All amounts are **magnitudes**; the direction already carries the sign. `ownCents` = units on the category itself, `rollupCents` = own + all descendants. `parentCategoryUuid` comes from the built tree, so a category whose parent is gone is promoted to top level instead of hiding its amounts.

**`MonthlyCategoryReport`** — `rows` (flat, every category with a non-zero rollup, sorted `rollupCents` DESC), `uncategorizedCents`, `totalCents` (everything in scope, including uncategorized). Helpers: `empty`, `isEmpty`, `categorizedCents`, `childrenOf(String? parentUuid)`, `hasChildren(uuid)`, `rowFor(uuid)`. Flat on purpose: the screen slices it per drilldown level.

`MonthlyReportPoint` — one month of a series: `year`, `month`, `report`, getter `monthStart`. Travels next to the report (not inside it) so `MonthlyCategoryReport.empty` can stay `const`.

## Service — `domain/monthly_category_report_service.dart`
`MonthlyCategoryReportService(transactionRepo, lineItemRepo, categoryRepo, accountRepo)`.

`Future<MonthlyCategoryReport> compute({required int year, required int month, String? accountUuid, required ReportDirection direction})` — now a thin wrapper: delegates to `computeSeries` with `windowMonths: 1` and returns its single point's report (`MonthlyCategoryReport.empty` if the series comes back empty).

`Future<List<MonthlyReportPoint>> computeSeries({required DateTime anchorMonth, required int? windowMonths, String? accountUuid, required ReportDirection direction})` — the months `[anchor − (windowMonths − 1) … anchor]`, oldest first.

- Bookings, positions and the category tree each load **once** for the whole span; the per-month loop only re-aggregates.
- Bookings come from `TransactionRepository.findByAccount`; with `accountUuid == null` it loops `AccountRepository.findAll()` (non-archived only, so an archived account drops out).
- `windowMonths == null` starts the series at the first month with anything in scope, and returns `[]` when there is none. Otherwise the window is exactly `windowMonths` long regardless of data.
- A month with no bookings still gets a point, carrying `MonthlyCategoryReport.empty` — the forecast needs a contiguous series, and a gap is a real zero.
- Direction is decided on the **booking's** sign, not per position, so an opposing Restposten stays with its booking.
- Counting unit: a position when the booking has any active ones, otherwise the booking itself.
- A position's category always comes from `effectiveCategoryUuid` (drilldown resolver), never from `LineItem.categoryUuid` directly.
- Positions load in one query via `LineItemRepository.findByTransactions`.
- Categories load with `includeArchived: true`, so an archived category still carries its amounts.
- A `categoryUuid` pointing at a category that no longer exists counts as uncategorized rather than vanishing.
- Sums stay signed internally and become magnitudes only at the row edge (`abs()`), so a subtree can net against itself.
- Rollup walks `buildCategoryTree`; a parent netting to zero keeps its row while a descendant has one, or that descendant would have no level to sit on.
- The report trusts the Restposten invariant from ticket 019: positions add up to their booking, so replacing a booking by its positions loses nothing.

## Forecast — `domain/forecast.dart`
`minimumForecastMonths = 3` — fewer filled months than this and a line is not fit.

**`MonthValue`** — one month, magnitude only: `year`, `month`, `cents`, getter `monthStart`.

**`LinearFit`** — `slope` (cents/month), `intercept` (value at `x = 0`), `r2`, `valueAt(int x)`. `fitLinear(List<int> values)` is ordinary least squares over `x = 0 … n−1`; `r2` is `0` for a series with no variance (a flat series is not a perfect fit, and `0/0` must not surface as `NaN`).

**`ForecastResult`** — `history`, `forecast` (both `List<MonthValue>`), `slopeCentsPerMonth`, `interceptCents` (fitted value at the first history month), `r2`. `.insufficient(history)` sets an empty `forecast` and zeroed slope/intercept/r2; `.empty` is `.insufficient(<MonthValue>[])`. `hasForecast` = `forecast.isNotEmpty`. `fittedCentsAt(int x)` = the fitted line at month index `x` counted from the first history month.

**`ForecastFilter`** — value-equal (provider family key). Ctor + `.of(DateTime anchor, {categoryUuid, ...})`.

| Field | Type | Notes |
|-------|------|-------|
| `categoryUuid` | String | |
| `anchorYear` / `anchorMonth` | int | getter `anchor` |
| `accountUuid` | String? | `null` = all non-archived accounts |
| `direction` | `ReportDirection` | default `expenses` |
| `windowMonths` | int? | default `12`; `null` = all history |
| `horizonMonths` | int | default `6` |

Copy helpers: `withCategory`, `withAccount`, `withDirection`, `withWindow`, `withHorizon`.

## Forecast service — `domain/forecast_service.dart`
`ForecastService(monthlyCategoryReportService)`, one method:
`Future<ForecastResult> compute({required String categoryUuid, required DateTime anchorMonth, required int? windowMonths, required int horizonMonths, String? accountUuid, required ReportDirection direction})`.

- Calls `computeSeries` for the history, then reads each point's value as `rowFor(categoryUuid)?.rollupCents ?? 0` — same rollup the report shows, so forecast and report can never disagree about what a month was worth.
- History shorter than `minimumForecastMonths` → `ForecastResult.insufficient(history)`.
- Otherwise `fitLinear` over the history's cents, then one `MonthValue` per horizon month, each floored at `0` (a falling trend runs through zero eventually; negative spending is not a thing).

## Providers — `domain/analytics_providers.dart`
- `monthlyCategoryReportServiceProvider`, `forecastServiceProvider` (built on top of it).
- `monthlyCategoryReportProvider` — `StreamProvider.family<MonthlyCategoryReport, MonthlyReportFilter>`.
- `forecastProvider` — `StreamProvider.family<ForecastResult, ForecastFilter>`.
- Both emit an initial snapshot, then recompute on the shared private `_dataChanges(isar)` — a `StreamGroup.merge` of `watchLazy()` over `transactions`, `lineItems`, `categorys`, `accounts`. Mirrors `LocalBalanceService`.

The file imports the four entity libraries because the Isar collection getters are extensions from their `.g.dart` parts.

## UI (`presentation/`)
**`MonthlyCategoryReportScreen`** — owns the filter state. Month row (prev/next arrows + tap → `showDatePicker` opened in year mode), account chip (`Alle Konten` default), `SegmentedButton` Ausgaben/Einnahmen. Empty state: `Keine Transaktionen für <Monat>`.

**`ReportLevelView`** — donut + table for one level, reused by both screens. Uncategorized renders as a muted first row labelled `Ohne Kategorie` and is **excluded** from the donut. Slice labels below 8 % are dropped (text would not fit the arc). A row is tappable only when the category has children.

**`CategorySubtreeReportScreen`** — children of one category. Carries the filter it was pushed with (fixed, shown as `<Monat> · Ausgaben` under the app-bar title) so both levels always describe the same month. The parent's own amounts render as a non-tappable first row `<Name> (direkt)` with its own slice, which makes the drilldown total equal the `rollupCents` of the row that was tapped.

**`account_filter_sheet.dart`** — `pickAccount(context, {selected}) → Future<AccountPick?>`; `AccountPick(null)` means all accounts, a `null` return means dismissed (same load-bearing distinction as `CategoryPick`).

Amounts render through `formatCentsEur`; month labels through `formatMonthYearDe` (`lib/core/format/date_format.dart`), which spells German month names out rather than pulling intl locale data.

**`ForecastScreen({initialFilter})`** — no filter → `Kategorie wählen, um eine Prognose zu sehen`. With one, an `fl_chart` `LineChart` carrying three bars, in order:

| Bar | Style | Content |
|-----|-------|---------|
| Fitted line | thin, no dots | `fittedCentsAt(0)` → `fittedCentsAt(lastHistoryIndex)` |
| History | dots | one spot per history month |
| Projection | dashed | repeats the last history spot first, so it connects, then one spot per forecast month |

Below the chart: `Trend +12,34 € pro Monat` (`slopeCentsPerMonth`) with subtitle `Anpassungsgüte NN %` (`r2 * 100`, rounded); one row per projected month labelled `MM/YYYY`.

Controls: category chip (`CategoryChip`, tap → `pickCategory`), account chip (`pickAccount`), direction `SegmentedButton`, `Fenster` (3/6/12/Alle) and `Horizont` (3/6/12) `ChoiceChip` rows. Every control except the category picker is disabled until a category is chosen. Empty state when `hasForecast` is false: `Zu wenige Daten für Prognose (mindestens 3 Monate)`.

**Entry points**
- `Mehr` tab → `Prognose` tile (`MenuScreen`, see infrastructure.md) — pushed without a filter, so the anchor is the current month and the category is picked in the screen.
- Deep link from the report — **long-press** a category row in `ReportLevelView`, or the `Prognose` app-bar action in `CategorySubtreeReportScreen`. Both call `ReportLevelView.openForecast(context, reportFilter:, categoryUuid:)`, which copies category, account, direction and the report's month into a `ForecastFilter`.
- The `(direkt)` pseudo row and the `Ohne Kategorie` row have no long-press — neither stands for a category.

**Behaviour**
- The value per month is that category's `rollupCents` (own + descendants) — identical to the report.
- A projection below zero is floored at `0`.
- `r2` is `0` for a series with no variance (a flat series is not a perfect fit, and `0/0` must not surface as `NaN`).

## Item price trends — `domain/item_price_trend.dart`
**`PricePoint`** — `date` (the parent booking's `bookingDate`), `unitPriceCents` (magnitude).

**`ItemGroup`** — `normalizedKey`, `label`, `purchaseCount`, `latestUnitPriceCents`, `latestDate`. `label` = spelling of most recent purchase, trimmed; one spelling per casing/whitespace variant, newest is best guess at current usage.

**`ItemPriceSeries`** — `normalizedKey`, `label`, `points` (oldest first). Getters: `isEmpty`, `count`, `minUnitPriceCents`, `maxUnitPriceCents` (both `null` when empty). Named ctor `.emptyFor(key)`.

## Item price trend service — `domain/item_price_trend_service.dart`
`ItemPriceTrendService(transactionRepo, lineItemRepo, accountRepo)`, two methods:
- `Future<List<ItemGroup>> searchGroups(String query)` — query normalized; blank → `[]`; substring match on normalized key; sorted `purchaseCount` DESC, ties by `label` ASC.
- `Future<ItemPriceSeries> series(String normalizedKey)` — normalizes argument, `.emptyFor(key)` for unknown key.

**Grouping & pricing**
- Grouping key = `normalizeForMatching` (`lib/core/text/normalize.dart`) — same as dedupe/tagging. Different sorts stay separate (`h-milch 1,5 %` vs `h-milch 3,5 %`); OCR spelling variants also separate, no fuzzy merge.
- Unit price per purchase, priority: printed `unitPriceCents` → `round(abs(amountCents) / quantity)` when quantity set → `abs(amountCents)`.
- `kind == restposten` excluded — managed row is a booking diff, not an article.
- Only positions count, never booking totals.
- Bookings per account via `AccountRepository.findAll()` + `TransactionRepository.findByAccount`, one `findByTransactions` bulk query — same repo boundary as monthly report. Archived accounts, soft-deleted bookings and positions drop out.

## Item price trend providers — `domain/analytics_providers.dart`
- `itemPriceTrendServiceProvider`.
- `itemGroupSearchProvider` — `StreamProvider.autoDispose.family<List<ItemGroup>, String>`, key = raw query.
- `itemPriceSeriesProvider` — `StreamProvider.autoDispose.family<ItemPriceSeries, String>`, key = normalized key.
- Both emit initial snapshot, recompute on `_dataChanges(isar)`, same as report and forecast. `autoDispose` because family key is user text.

## Item price chart UI (`presentation/`)
**`ItemPriceTrendScreen`** — app-bar `Preistrends`, `TextField` (`Artikel suchen`) debounced 300 ms. Blank → `Artikel suchen, um seinen Preisverlauf zu sehen`. No hits → `Keine Artikel gefunden`. Row shows label, purchase count (singular/plural), latest unit price, chevron; tap pushes chart.

**`ItemPriceChartScreen({normalizedKey, title})`** — raw spelling as `title` (normalized key is lookup only). `0` points → `Keine Käufe erfasst`; exactly `1` → `Nur ein Datenpunkt (X,XX €) — kein Trend darstellbar`; else `fl_chart` `LineChart` with one bar, one dot per purchase. X = days since first purchase (real time axis, 8-week gap reads as one), collapsed to `1` when one day. Y padded around min/max, **no zero anchor**. Min/max are `extraLinesData` horizontal dashed, labelled `Max <price>` / `Min <price>`, collapsing to single `Preis <price>` line when all equal; extreme dots drawn larger. Below chart: `<n> Käufe erfasst` + `Zuletzt <price> am <dd.MM.yyyy>`.

- Amounts render through `formatCentsEur`, dates through `formatDateDe`.

**Entry points**
- `Mehr` tab → `Preistrends` tile (`MenuScreen`).
- Long-press on position row in `LineItemsSection` (Drilldown) pushes that row's history directly, normalizing description as key. Restposten row has no long-press.
