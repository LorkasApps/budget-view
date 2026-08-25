# Net result per month, and a yearly view

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Analytics |
| **Domain** | Analytics |
| **Blocked By** | None |
| **Status** | Ready |

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

## Resolved during refinement
- **A mode of the report screen, not a second surface**: a `Monat` / `Jahr` switch. In year mode the screen shows twelve rows —
  one per month with income, expenses and net — plus the year's three figures above them. The category table belongs to month
  mode; in year mode the month breakdown **is** the table. Reasons: `computeSeries` (021) already produces exactly this in one
  load, one surface keeps one set of filters, and "how did the months develop" is what a year answers — a category table across
  twelve months is the wrong tool for it. A separate screen behind `Mehr` was rejected: it would compete with the forecast and
  the price trends and duplicate the filters
- **Years are stepped with arrows plus the year label**, no `DatePicker`. Month mode lives with the Material picker and its
  irrelevant day (`decisions.md`, 2026-08-20); repeating that crutch one level up would be worse than two arrows that do exactly
  what is wanted
- **The direction filter belongs to the table and the donut, not to the result figures.** The monthly net and the twelve yearly
  rows always show both directions — a "result" under an active `Ausgaben` filter would be the expense sum wearing the wrong
  name. In year mode the direction filter is hidden, since there is no table for it to act on and a filter without effect is
  worse than none. The rule from `decisions.md` (2026-08-18) that direction is decided at the **booking** stays untouched; new is
  only that this screen now carries figures the filter does not touch
- **The account filter applies everywhere** — it decides which bookings count at all
- **The monthly result sits as a line above the donut**: `Einnahmen`, `Ausgaben`, `Ergebnis`, and the result is shown **with its
  sign** (`+412,18 €` / `−93,07 €`). That is the deliberate exception to this screen's magnitudes-only rule
  (`decisions.md`, 2026-08-18) — a result without a sign carries no information
- **Calendar year**, not a rolling twelve months. The mode is called `Jahr`, shows twelve named months, and the arrows step from
  2025 to 2026. Rolling windows are the forecast's language (021, `windowMonths`); two notions of time on one surface would
  confuse both
- **An empty month or year shows zeros**, no special state: "nothing happened" and "balanced" are both 0, and the table has its
  own empty state already

## Acceptance Criteria
- [ ] Month mode shows a line above the donut with `Einnahmen`, `Ausgaben` and a signed `Ergebnis`
- [ ] Transfers are excluded from all three figures, on the same basis as the rows below them
      (`decisions.md`, 2026-08-21)
- [ ] A `Monat` / `Jahr` switch changes the mode without leaving the screen
- [ ] Year mode lists twelve rows — one per month, each with income, expenses and net — plus the year's three figures
- [ ] Year mode steps years with arrows and a year label, and shows no category table and no direction filter
- [ ] The account filter applies in both modes; the direction filter applies only to the table and donut of month mode
- [ ] The year's figures equal the sum of its twelve rows, and each month row equals what month mode shows for that month
- [ ] The data comes from `computeSeries`; no second aggregation over bookings is written
- [ ] An empty month and an empty year show zeros
- [ ] `make check` green

## Out of Scope (proposed, to confirm)
- Budgets or targets to compare the result against
- Multi-year comparison, and anything about the forecast (021), which answers a different question

## Affected Tests
- The report service tests, if the net is computed there; the report screen widget tests for the new figure
- A yearly view built on `computeSeries` inherits its tests and needs its own for the aggregation over the series

## Fixtures Needed
No. Bookings across a few months built inline, including one transfer that must stay out of every figure.

### Refinement Tokens (estimate)
- Input: ~12k tokens
- Output: ~2.5k tokens

### Implementation Tokens (estimate)
_Filled after Done._
