# Forecast (linear regression)

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Analytics |
| **Domain** | Analytics |
| **Blocked By** | 020 |
| **Status** | Done |

## Description
Simple ordinary-least-squares linear regression on monthly totals per category, projecting 3 / 6 / 12 months into the future. Both the history window (used for fit) and the forecast horizon are user-selectable. Uses the same category-aggregation service as ticket 020 (`MonthlyCategoryReportService`) so numbers stay consistent between report + forecast.

## Math

Given monthly totals `y_1, y_2, ..., y_n` at month-indices `x_1, x_2, ..., x_n` (contiguous months, missing months → `0`):

```
slope β = Σ((xᵢ − x̄)(yᵢ − ȳ)) / Σ((xᵢ − x̄)²)
intercept α = ȳ − β · x̄
forecast(x) = α + β · x
```

Amounts are magnitudes (`abs(amountCents)`) for the selected direction (Ausgaben / Einnahmen), consistent with the report. Missing months in the window are filled with `0` (no activity that month).

## Filters / Inputs

| Filter | Values | Default |
|--------|--------|---------|
| Category | picker over category tree | none (empty state until picked) |
| Direction | `Ausgaben` \| `Einnahmen` | `Ausgaben` |
| Account | `all` \| specific `accountUuid` | `all` |
| History window | `3` \| `6` \| `12` \| `all` | `12` |
| Forecast horizon | `3` \| `6` \| `12` | `6` |
| Anchor month | last month of the history window | current month; the report's selected month when opened from a report row |

The window is `[anchor − (window − 1) … anchor]`, the projection `[anchor + 1 … anchor + horizon]`. `all` starts at the first month that has any booking in scope.

## Data Requirements

- Minimum data points to fit: **3** filled monthly totals within the window (a `0`-filled month counts). Below → screen shows empty state `"Zu wenige Daten für Prognose (mindestens 3 Monate)"`.
- All monthly totals come through the same `effectiveCategoryUuid` rollup as ticket 020, but limited to the selected category (own + descendants, mirroring the report's rollup semantics).

## Acceptance Criteria
- [x] `MonthlyCategoryReportService.computeSeries({required DateTime anchorMonth, required int? windowMonths, String? accountUuid, required ReportDirection direction})` → `List<MonthlyReportPoint>` (oldest first, one per month, gaps included as `MonthlyCategoryReport.empty`). The point carries `year` + `month` alongside the report — a bare report cannot say which month it describes, and `MonthlyCategoryReport.empty` has to stay `const` for the report screen. Loops the months internally and loads categories + tree **once**, so the resolver, rollup, direction and uncategorized rules stay in the single place that already owns them
- [x] `ForecastService` in `lib/features/analytics/domain/forecast_service.dart`:
  - `Future<ForecastResult> compute({required String categoryUuid, required DateTime anchorMonth, required int? windowMonths, required int horizonMonths, String? accountUuid, required ReportDirection direction})`
  - `windowMonths == null` means "all available history" — no `-1` sentinel, `null` is how this codebase spells "not set" (decisions.md, 2026-08-12)
  - Reads each month's value as `rowFor(categoryUuid).rollupCents` from `computeSeries`, i.e. own + descendants, identical to the report's rollup
  - Computes OLS slope + intercept in pure Dart (no external stats lib needed)
  - Returns `ForecastResult { history: List<MonthValue>, forecast: List<MonthValue>, slopeCentsPerMonth: double, r2: double }`
- [x] `r2` (coefficient of determination) computed and returned; UI renders it as a small quality indicator ("Anpassungsgüte"). A series with zero variance in `y` (flat, or every month `0`) has no explainable variance — `r2` is `0.0` there, not `NaN`
- [x] `forecastServiceProvider` (Riverpod, family) exposes the service
- [x] Forecast screen (`ForecastScreen`):
  - Category picker (tree)
  - Direction / Account / Window / Horizon toggles
  - Chart (`fl_chart` LineChart): x-axis = months (past + future), y-axis = magnitude; historical points as dots, best-fit line, forecast points as dashed continuation
  - Sidebar / footer: predicted values for each future month with formatted EUR
  - Empty state when < 3 data points
- [x] Two entry points, both tested:
  - `AppShell` gains a third tab `Prognose` — anchor = current month, category chosen in the screen's own picker
  - `CategorySubtreeReportScreen` and the report's rows offer a forecast action that deep-links with category, account, direction and the report's month already filled in, so the two screens cannot disagree on the numbers they show
- [x] Reactivity: series re-computes when any input changes, and on writes to the four collections (same `StreamGroup` wiring as `monthlyCategoryReportProvider`)
- [x] Pure functional forecast core unit-tested with known-answer fixtures (trivial linear series → exact slope, flat series → slope 0, noisy series → within tolerance)

## Affected Tests
- `test/features/analytics/domain/forecast_service_test.dart` — known-linear, flat, noisy, sparse (<3 pts), window edges, direction filter
- `test/features/analytics/domain/forecast_r2_test.dart` — r² for perfect fit == 1.0, for flat data ≈ 0
- `test/features/analytics/presentation/forecast_screen_test.dart` — toggles, empty state, chart renders forecast segment

## Fixtures Needed
No — inline arithmetic fixtures.

## Refinement Tokens (estimate)
- Input: ~11k tokens
- Output: ~3k tokens

### Implementation Tokens (estimate)
- Input: ~150k tokens (incl. ~74k in one docs sub-agent)
- Output: ~26k tokens

## Deviations from the refined ticket
- `ForecastResult` also carries `interceptCents` (+ `fittedCentsAt(x)`): without it the chart cannot draw the best-fit line the ACs ask for.
- `windowMonths == null` replaces the proposed `-1` sentinel (decisions.md).
- The row-level entry point is a **long-press**, not a visible per-row action: a third widget in `ListTile.trailing` is the overflow that errors.md already records.

## Open verification
The `LineChart` has never rendered a frame — widget tests assert bar data only.
Axis crowding, chip-row overflow and whether the long-press entry point is
discoverable are checked in **028** (milestone-1 verification pass).
