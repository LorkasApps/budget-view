# Year mode switches between a monthly and a category breakdown

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Analytics |
| **Domain** | Analytics |
| **Blocked By** | None (051 overlaps — see Open questions) |
| **Status** | Draft |

## Description
Month mode answers "where did it go" through a direction switch: `Ausgaben` or `Einnahmen`, one category tree at a time.
Year mode (ticket 052) answers only "when did it go" — twelve month rows and the year's three figures. The category
dimension is missing for the year: there is no way to ask "what did groceries cost me in 2026", only to ask it twelve times.

So the year gets its own switch, next to the figures it already shows: a breakdown **per month** (today's `YearResultView`)
or a breakdown **per category** (month mode's donut + tree table, computed over twelve months instead of one).

## What is already settled and must hold
- The yearly view is a **mode of the report screen**, not a new surface (ADR 0144). This ticket adds a second axis inside
  that mode, not a third tab.
- The monthly series is `computeSeries()` on the existing service, not N × `compute()` and not an extracted helper
  (ADR 0084). Any year-wide rollup is reached through that method, not a new query path.
- Transfers are excluded before rollup, the counting unit is the position where a booking has active ones, and the category
  of a position comes from `effectiveCategoryUuid`. A year rollup inherits all three — it adds arithmetic, not policy.
- The mode never touches `MonthlyReportFilter`, so the selected month survives a trip through year mode.
- `ReportLevelView` (donut + table) is already shared by two screens; the year category view is a third caller, not a copy.

## Open questions for refinement
1. **Direction.** A category tree mixing income and expenses has no meaning, so the category breakdown needs a direction —
   but 052 deliberately *hides* the direction filter in year mode because no table was left for it to act on. Does the
   filter come back when `Kategorien` is selected, and disappear again under `Monate`?
2. **Where the year rollup comes from.** `computeSeries(windowMonths: 12)` yields twelve per-month reports; one year tree
   means folding those twelve trees into one. Alternative: give the rollup a month span so it aggregates once over the
   whole year. Folding reuses settled code and costs a tree merge; a span parameter touches the service's signature but
   avoids merging rollup totals by hand. Recommendation: the span parameter, because a merged tree has to re-derive
   `rollupCents` per node anyway and that is exactly what the rollup walk already does.
3. **Drilldown.** `CategorySubtreeReportScreen` labels itself `<Monat> · Ausgaben`. Is a year row tappable into the subtree
   screen, and does that label become `2026 · Ausgaben`?
4. **The result line.** Does `ResultSummaryLine` stay above the donut under `Kategorien`, as it does in month mode?
5. **Overlap with 051.** 051 caps the tree at roots plus one child level. If 051 lands first, the year category table
   inherits the cap for free; if this one lands first, the depth question is answered twice. Should 065 be `Blocked By: 051`?
6. **Control shape.** A third `SegmentedButton` in a filter row that already holds a period row, an account chip and the
   `Monat`/`Jahr` switch — or does `Monate` / `Kategorien` replace the direction switch's slot?

## Acceptance Criteria (proposed, to confirm in refinement)
- [ ] In year mode a switch offers `Monate` and `Kategorien`; `Monate` is the default and is today's `YearResultView`
- [ ] `Kategorien` shows the donut and category table for the whole selected year, with the same row and slice rules as
      month mode (`Ohne Kategorie` muted and out of the donut, slices under 8 % unlabelled)
- [ ] The category figures over a year equal the sum of the twelve months month mode shows for that year
- [ ] The account filter applies to both breakdowns; the period arrows keep stepping ±12 months in both
- [ ] Switching `Monate` ↔ `Kategorien` keeps the selected year, and switching `Jahr` → `Monat` → `Jahr` keeps the
      breakdown choice
- [ ] An empty year shows the table's own empty state under `Kategorien` and zeros under `Monate`
- [ ] No second aggregation over bookings is written — the year rollup goes through the existing report service
- [ ] `make check` green

## Out of Scope (proposed)
- A free span other than one calendar year (`Letzte 12 Monate` and the like)
- A category breakdown in the drilldown screen for a year, if question 3 is answered "not tappable"
- Changing the forecast's deep link, which stays month-anchored

## Affected Tests
- `test/features/analytics/` — service tests for the year rollup, widget tests for the new switch and the year category body
- Widget tests run at 1200 px, so any new column width is a device-check item, not a test (see 052)

## Fixtures Needed
Open — ask during refinement.
