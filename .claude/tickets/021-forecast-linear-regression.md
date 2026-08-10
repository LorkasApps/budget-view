# Forecast (linear regression)

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Analytics |
| **Domain** | Analytics |
| **Blocked By** | 020 |
| **Status** | Ready |

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

## Data Requirements

- Minimum data points to fit: **3** filled monthly totals within the window (a `0`-filled month counts). Below → screen shows empty state `"Zu wenige Daten für Prognose (mindestens 3 Monate)"`.
- All monthly totals come through the same `effectiveCategoryUuid` rollup as ticket 020, but limited to the selected category (own + descendants, mirroring the report's rollup semantics).

## Acceptance Criteria
- [ ] `ForecastService` in `lib/features/analytics/domain/forecast_service.dart`:
  - `Future<ForecastResult> compute({required String categoryUuid, required int windowMonths, required int horizonMonths, String? accountUuid, required ReportDirection direction})`
  - `windowMonths == -1` (or a sentinel like `ForecastWindow.all`) means "all available history"
  - Builds monthly-total series via the same aggregation service used by 020 (reuse or extract shared helper)
  - Computes OLS slope + intercept in pure Dart (no external stats lib needed)
  - Returns `ForecastResult { history: List<MonthValue>, forecast: List<MonthValue>, slopeCentsPerMonth: double, r2: double }`
- [ ] `r2` (coefficient of determination) computed and returned; UI renders it as a small quality indicator ("Anpassungsgüte")
- [ ] `forecastServiceProvider` (Riverpod, family) exposes the service
- [ ] Forecast screen (`ForecastScreen`):
  - Category picker (tree)
  - Direction / Account / Window / Horizon toggles
  - Chart (`fl_chart` LineChart): x-axis = months (past + future), y-axis = magnitude; historical points as dots, best-fit line, forecast points as dashed continuation
  - Sidebar / footer: predicted values for each future month with formatted EUR
  - Empty state when < 3 data points
- [ ] Reactivity: series re-computes when any input changes
- [ ] Pure functional forecast core unit-tested with known-answer fixtures (trivial linear series → exact slope, flat series → slope 0, noisy series → within tolerance)

## Affected Tests
- `test/features/analytics/domain/forecast_service_test.dart` — known-linear, flat, noisy, sparse (<3 pts), window edges, direction filter
- `test/features/analytics/domain/forecast_r2_test.dart` — r² for perfect fit == 1.0, for flat data ≈ 0
- `test/features/analytics/presentation/forecast_screen_test.dart` — toggles, empty state, chart renders forecast segment

## Fixtures Needed
No — inline arithmetic fixtures.

## Refinement Tokens (estimate)
- Input: ~11k tokens
- Output: ~3k tokens

## Token Usage
_Filled after Done._
