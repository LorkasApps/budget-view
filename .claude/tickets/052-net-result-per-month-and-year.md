# Net result per month, and a yearly view

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Analytics |
| **Domain** | Analytics |
| **Blocked By** | None |
| **Status** | Draft |

## Description
The monthly report answers "where did it go" one direction at a time: the direction filter shows expenses **or** income, so
the figure the user actually steers by — did the month end in plus or minus — is nowhere on screen. Wanted:

1. the month's **net result** (income minus expenses) beside the expenses-vs-income view
2. the same on a **yearly** basis, as the big-scope view

## What is already settled and must hold
- **Transfers stay out.** Money moved between own accounts is neither income nor spending; the report excludes it
  (`decisions.md`, 2026-08-21), so the net must be computed on the same basis or it will contradict the rows above it
- **Sums are signed internally, magnitudes only at the row edge** (`decisions.md`, 2026-08-18). A net result is the one figure
  that needs its sign shown, which is the opposite of every other number on that screen
- **`computeSeries()` already exists** (ticket 021): one pass produces a month-by-month series over the same rollup, loading
  bookings, line items and the category tree once. A yearly view is twelve of its points, so the data layer may need nothing
  new at all — worth checking before writing a second aggregation

## Open questions for refinement
- **Where does the monthly net live?** A line in the existing report header, its own card above the donut, or beside the
  existing total? It has to read as a result, not as another category row
- **What is the yearly view — a mode of the report screen or its own surface?** A year mode needs a year picker; the month
  picker is deliberately the Material `DatePicker` with its irrelevant day (`decisions.md`, 2026-08-20). Reusing that widget
  for a year would repeat that compromise one level up
- Does the yearly view break down by month (twelve rows or bars, each with income, expenses and net) or only show the year's
  three figures? The first is more useful and is exactly what `computeSeries` returns
- Does the yearly view keep the category table, or is it purely the three figures over time? A year of categories is a
  different question from a year of results
- Do the account and direction filters apply? Direction is meaningless for a net result — does picking it disable the filter,
  or does the net ignore the filter and say so?
- Which months count in the year: calendar year, or the last twelve months? The forecast already thinks in windows
- What does an empty month or an empty year show — zero, or "no bookings"?

## Acceptance Criteria
_Not refined yet._

## Out of Scope (proposed, to confirm)
- Budgets or targets to compare the result against
- Multi-year comparison, and anything about the forecast (021), which answers a different question

## Affected Tests
- The report service tests, if the net is computed there; the report screen widget tests for the new figure
- A yearly view built on `computeSeries` inherits its tests and needs its own for the aggregation over the series

## Fixtures Needed
Ask during refinement.

## Token Usage
_Filled after Done._
