# Net result per month, and a yearly view

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Analytics |
| **Domain** | Analytics |
| **Blocked By** | None |
| **Status** | In Progress |

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
- [x] Month mode shows a line above the donut with `Einnahmen`, `Ausgaben` and a signed `Ergebnis`
- [x] Transfers are excluded from all three figures, on the same basis as the rows below them
      (`decisions.md`, 2026-08-21) — inherited, not re-implemented: the figures are `computeSeries`' own `totalCents`
- [x] A `Monat` / `Jahr` switch changes the mode without leaving the screen
- [x] Year mode lists twelve rows — one per month, each with income, expenses and net — plus the year's three figures
- [x] Year mode steps years with arrows and a year label, and shows no category table and no direction filter
- [x] The account filter applies in both modes; the direction filter applies only to the table and donut of month mode
- [x] The year's figures equal the sum of its twelve rows, and each month row equals what month mode shows for that month —
      structural: `ResultSeries`' three getters fold over its points, so a one-month series *is* its own row
- [x] The data comes from `computeSeries`; no second aggregation over bookings is written — two calls, one per direction,
      zipped by index (`decisions.md`, 2026-09-08)
- [x] An empty month and an empty year show zeros
- [x] **Added during implementation:** a month row in year mode taps back into month mode for that month — seeing an
      outlier in the year is the moment its categories are wanted. No chevron: the four columns carry no fifth widget
- [x] `make check` green — 614 passed, 6 skipped (2026-09-08), against 596 before

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
- Input: ~70k tokens
- Output: ~11k tokens

## How it was built
- **`ResultFilter` owns the mode→window mapping** (`domain/result_series.dart`): `month == null` means the calendar year,
  and `anchorMonth` / `windowMonths` translate that into the language `computeSeries` already speaks. The service method
  therefore has no notion of "month mode" or "year mode", and the domain test drives it through the filter so the mapping
  is covered by the same cases as the arithmetic.
- **`ResultSeries`' three getters fold over its points**, which is what makes two acceptance criteria structural instead of
  tested-by-coincidence: the year equals the sum of its rows, and a one-month series equals the row that month shows. The
  screen reads the same three getters in both modes.
- **The filter deliberately carries no direction.** A result covers both, so a direction in the family key would recompute
  and cache twice on every `Ausgaben`/`Einnahmen` tap while producing identical figures.
- **The result line is fed by its own provider**, so it renders above an empty month's empty state. In month mode it reads
  `valueOrNull` — the report area below reports a failure, and two error texts for one cause would be noise. Year mode has
  nothing below it, so there `.when` carries its own message.
- **`ResultSummaryLine` doubles as the header row of the year table** via `leadingLabel`; shared `_labelFlex` /
  `_figureFlex` are what keep the twelve rows aligned under it. Every cell is `maxLines: 1` + ellipsis, because
  `September` next to three amounts is the tight case on a phone.
- Known shape of the widget tests: `Einnahmen` and `Ausgaben` are now **both** the direction segments and the result
  line's labels, so `find.text` is ambiguous on this screen. The tests scope through
  `find.descendant(of: find.byType(ResultSummaryLine))` resp. `SegmentedButton<ReportDirection>`, and the result fake uses
  amounts that appear nowhere in the report fake — an assertion must not pass by matching a number from the table.
- `app_shell_test.dart` needed the new override too: the shell builds the report tab, and the real provider reaches for
  Isar, which never completes inside `testWidgets`.

## Device check
The one thing `make check` cannot see: the widget tests run at 1200 px width, while four columns next to `September` on a
360 px phone are the tight case. `maxLines: 1` + ellipsis means a miss shows as `…`, not as an overflow error.

- [ ] `Report` tab, a month that has bookings: the line above the donut reads `Einnahmen`, `Ausgaben`, `Ergebnis`, and none
      of the three amounts is cut off with `…`
- [ ] `Jahr` tapped: twelve rows `Januar` … `Dezember`, and in the `September` row neither the month name nor any of its
      three amounts is cut off
- [ ] A month row tapped: the screen stands in month mode on exactly that month, with the donut and the
      `Ausgaben` / `Einnahmen` switch back
- [ ] A positive `Ergebnis` is green with a leading `+`, a negative one red with `-`, and both are legible under
      `Einstellungen` → theme `Dunkel` as well as `Hell`
