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

## Service — `domain/monthly_category_report_service.dart`
`MonthlyCategoryReportService(transactionRepo, lineItemRepo, categoryRepo, accountRepo)`, one method:
`Future<MonthlyCategoryReport> compute({required int year, required int month, String? accountUuid, required ReportDirection direction})`.

- Bookings come from `TransactionRepository.findByAccount`; with `accountUuid == null` it loops `AccountRepository.findAll()` (non-archived only, so an archived account drops out).
- Month window is `[monthStart, nextMonthStart)`, filtered in Dart — the repository has no date-range query.
- Direction is decided on the **booking's** sign, not per position, so an opposing Restposten stays with its booking.
- Counting unit: a position when the booking has any active ones, otherwise the booking itself.
- A position's category always comes from `effectiveCategoryUuid` (drilldown resolver), never from `LineItem.categoryUuid` directly.
- Positions load in one query via `LineItemRepository.findByTransactions`.
- Categories load with `includeArchived: true`, so an archived category still carries its amounts.
- A `categoryUuid` pointing at a category that no longer exists counts as uncategorized rather than vanishing.
- Sums stay signed internally and become magnitudes only at the row edge (`abs()`), so a subtree can net against itself.
- Rollup walks `buildCategoryTree`; a parent netting to zero keeps its row while a descendant has one, or that descendant would have no level to sit on.
- The report trusts the Restposten invariant from ticket 019: positions add up to their booking, so replacing a booking by its positions loses nothing.

## Providers — `domain/analytics_providers.dart`
- `monthlyCategoryReportServiceProvider`
- `monthlyCategoryReportProvider` — `StreamProvider.family<MonthlyCategoryReport, MonthlyReportFilter>`; emits an initial snapshot, then recomputes on a `StreamGroup.merge` of `watchLazy()` over `transactions`, `lineItems`, `categorys`, `accounts`. Mirrors `LocalBalanceService`.

The file imports the four entity libraries because the Isar collection getters are extensions from their `.g.dart` parts.

## UI (`presentation/`)
**`MonthlyCategoryReportScreen`** — owns the filter state. Month row (prev/next arrows + tap → `showDatePicker` opened in year mode), account chip (`Alle Konten` default), `SegmentedButton` Ausgaben/Einnahmen. Empty state: `Keine Transaktionen für <Monat>`.

**`ReportLevelView`** — donut + table for one level, reused by both screens. Uncategorized renders as a muted first row labelled `Ohne Kategorie` and is **excluded** from the donut. Slice labels below 8 % are dropped (text would not fit the arc). A row is tappable only when the category has children.

**`CategorySubtreeReportScreen`** — children of one category. Carries the filter it was pushed with (fixed, shown as `<Monat> · Ausgaben` under the app-bar title) so both levels always describe the same month. The parent's own amounts render as a non-tappable first row `<Name> (direkt)` with its own slice, which makes the drilldown total equal the `rollupCents` of the row that was tapped.

**`account_filter_sheet.dart`** — `pickAccount(context, {selected}) → Future<AccountPick?>`; `AccountPick(null)` means all accounts, a `null` return means dismissed (same load-bearing distinction as `CategoryPick`).

Amounts render through `formatCentsEur`; month labels through `formatMonthYearDe` (`lib/core/format/date_format.dart`), which spells German month names out rather than pulling intl locale data.

## Not in scope here
- Forecast (ticket 021)
- Item price trends (ticket 022)
