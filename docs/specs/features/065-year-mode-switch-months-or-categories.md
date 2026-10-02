# Year mode switches between a monthly and a category breakdown

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Analytics |
| **Domain** | Analytics |
| **Blocked By** | None |
| **Status** | Ready |

## Description
Month mode answers "where did it go" through a direction switch: `Ausgaben` or `Einnahmen`, one category tree at a time.
Year mode (ticket 052) answers only "when did it go" — twelve month rows and the year's three figures. The category
dimension is missing for the year: there is no way to ask "what did groceries cost me in 2026", only to ask it twelve times.

So the year gets its own switch, next to the figures it already shows: a breakdown **per month** (today's `YearResultView`)
or a breakdown **per category** — the same three columns, keyed by category instead of by month.

## What is already settled and must hold
- The yearly view is a **mode of the report screen**, not a new surface (ADR 0144). This ticket adds a second axis inside
  that mode, not a third tab.
- The monthly series is `computeSeries()` on the existing service, not N × `compute()` and not an extracted helper
  (ADR 0084). Any year-wide rollup is reached through that method, not a new query path.
- Transfers are excluded before rollup, the counting unit is the position where a booking has active ones, and the category
  of a position comes from `effectiveCategoryUuid`. A year rollup inherits all three — it adds arithmetic, not policy.
- The mode never touches `MonthlyReportFilter`, so the selected month survives a trip through year mode.
- Within a booking, sums already net: they stay signed internally and become magnitudes only at the row edge, so a
  Restposten rebates against its own booking. What does **not** net today is across bookings — direction is decided on the
  booking's sign, so a refund is its own booking and lands in the `Einnahmen` tree while the `Ausgaben` tree keeps the
  gross. That is the gap this ticket closes for the year.

## Resolved during refinement
**The category breakdown nets income against expenses, and therefore carries no direction filter and no donut**
(2026-10-02). Over twelve months a grocery refund is not noise: "what did food cost me in 2026" means net, and today that
figure appears nowhere — the gross sits in one tree and the rebate in the other. So the category view takes the shape the
month table already has, keyed by category instead of month:

```
2026           Einnahmen   Ausgaben   Ergebnis
Lebensmittel        50,00    -900,00   -850,00
Wohnen               0,00  -1.200,00 -1.200,00
Gehalt           3.600,00       0,00  +3.600,00
```

- It is `ResultSummaryLine` with `leadingLabel`, the very widget `YearResultView` uses per month — column flex, signed
  colour and the `maxLines: 1` ellipsis are inherited, not re-decided.
- No direction filter in year mode at all. Both directions stand side by side instead of being switched between, so 052's
  "the filter is hidden here" holds unchanged rather than becoming conditional.
- **No donut in year mode.** A netted row can be negative and a donut cannot draw a negative slice. Accepted cost: the
  year loses the visual share-of-total, which stays a month-mode affordance.
- `Monate` and `Kategorien` become two cuts of one table rather than two different screens.

**The year table lists root categories and drills down into a subtree** (2026-10-02). One row per root carrying its
rollup (own plus descendants); a row with children is tappable and pushes the subtree, which shows the same three columns
under the title `2026 · Lebensmittel`, with the parent's own amounts as a non-tappable first row `<Name> (direkt)` —
the same construction month mode uses, so the drilldown total again equals the `Ergebnis` of the row that was tapped.
Rejected: a flat root list (cheaper, but the year is where an outlier is spotted and the follow-up question is always
"in which subcategory"), and children inlined under their root (one surface, but the indent eats the label column, which
is already the tight case at 360 px).

**A row with children says so by weight, not by a trailing widget** (2026-10-02). The category name renders at
`fontWeight: w600` when the category has children and normally when it does not, so the affordance costs no width and
052's "the four columns carry no fifth widget" stands unamended. A chevron was rejected for exactly that reason: it would
shrink the label column, which was already the tight case at 360 px. Leaving the row unmarked was rejected because a
childless row would then swallow a tap in silence.

**Rows sort by the magnitude of `Ergebnis`, descending** (2026-10-02). Whatever moved the year most stands on top, in
either direction, so `Gehalt` and `Wohnen` end up as neighbours. Signed order was rejected because it buries the biggest
expense at the bottom of the list, and alphabetical because it says nothing about relevance. A consequence worth naming:
**`Ohne Kategorie` sorts in by magnitude like any other row** and is no longer pinned first as it is in month mode — it
keeps the muted style, but a 45 € remainder does not deserve the top of a yearly table.

**The rollup gets a month span and aggregates once per direction** (2026-10-02). A new
`computeSpan({fromMonth, toMonth, accountUuid, direction}) → MonthlyCategoryReport` walks the whole year in one pass; the
year table calls it twice, once per direction, and zips the two by `categoryUuid`. Folding the twelve monthly trees was
rejected: the merge would have to re-derive `rollupCents` per node, which is a second place for rollup arithmetic to live
and go wrong, while the rollup walk already does exactly that derivation. This stays inside ADR 0084's rule — the span is
another method on the existing report service, not a new query path — and inside 052's, because it is still one pass per
direction and no second aggregation over bookings.

**051 is not a blocker** (2026-10-02). Both the bold rule and the drilldown hang off "has children", never off a depth
number, so the view needs no change when 051 later caps the tree at roots plus one level: a child that loses its own
children simply stops being bold and stops being tappable. 065 therefore has to tolerate three-level data once — before
051 a subtree row can itself be tappable — which is a fixture concern, not a design one.

**The new switch takes the row the direction switch vacates** (2026-10-02). The filter area keeps its three rows in both
modes: period + account chip, then `Monat`/`Jahr`, then a third row that holds `Ausgaben`/`Einnahmen` in month mode and
`Monate`/`Kategorien` in year mode. **Month mode is not touched at all.** A fourth row was rejected because the third one
would then sit empty in year mode and the body would jump vertically on every mode switch; folding all of it into one
four-segment control was rejected because `Jahr: Kategorien` does not fit a segment at 360 px.

## Acceptance Criteria
- [ ] In year mode the third filter row offers `Monate` and `Kategorien`; `Monate` is the default and is today's
      `YearResultView`
- [ ] In month mode that row still offers `Ausgaben` and `Einnahmen`, unchanged
- [ ] `Kategorien` lists one row per root category for the selected year with `Einnahmen`, `Ausgaben` and a signed
      `Ergebnis`, in the same three columns and with the same header row as the month table, the year as `leadingLabel`
- [ ] A category's `Ergebnis` nets its income against its expenses, so a refund reduces the category's cost
- [ ] Rows sort by the magnitude of `Ergebnis`, descending; `Ohne Kategorie` sorts in like any other row and keeps the
      muted style
- [ ] A category with children renders its name at `fontWeight: w600` and is tappable; one without renders normally and
      does not react to a tap
- [ ] Tapping a row pushes the subtree with the same three columns, titled `2026 · <Name>`, with the parent's own amounts
      as a non-tappable first row `<Name> (direkt)`, so the subtree's `Ergebnis` sums to the tapped row's
- [ ] No donut and no direction filter anywhere in year mode
- [ ] A category's three figures equal the sum of what the twelve months contribute to that category
- [ ] The account filter applies to both breakdowns; the period arrows keep stepping ±12 months in both
- [ ] Switching `Monate` ↔ `Kategorien` keeps the selected year, and switching `Jahr` → `Monat` → `Jahr` keeps the
      breakdown choice
- [ ] An empty year shows zeros under `Monate` and the table's empty state under `Kategorien`
- [ ] The figures come from one `computeSpan` call per direction; no second aggregation over bookings is written
- [ ] `make check` green

## Out of Scope
- A free span other than one calendar year (`Letzte 12 Monate` and the like)
- A donut for the year, in either breakdown
- Netting across bookings in **month** mode — the direction filter and the donut stay as they are there
- A `Monate` / `Kategorien` choice inside the subtree screen; it follows whatever pushed it
- Changing the forecast's deep link, which stays month-anchored

## Affected Tests
- `test/features/analytics/` — `computeSpan` over a multi-month span, including a refund netting against an expense in the
  same category; widget tests for the third filter row, the category table's sort order, the bold-when-children rule and
  the subtree push
- Widget tests run at 1200 px, so any new column width is a device-check item, not a test (see 052)

## Fixtures Needed
No. The existing analytics fixtures carry the shapes this needs — a multi-month span, an opposing booking in a category
already used by an expense, and a three-level tree for the pre-051 subtree case. Extra bookings are added inline in the
tests that need them rather than as a new fixture.

## Device check
Widget tests run at 1200 px; four columns on a 360 px phone are the tight case and a miss shows as `…`, not as an
overflow error (same reason as 052).

- [ ] `Report` tab → `Jahr` → `Kategorien`: the header row reads the year plus `Einnahmen`, `Ausgaben`, `Ergebnis`, and no
      category name and no amount is cut off with `…`
- [ ] A category with children carries a visibly heavier name than one without
- [ ] That row tapped: the subtree stands under the title `2026 · <Name>` with `<Name> (direkt)` as its first row
- [ ] Back in the year table, `Monate` restores the twelve month rows and the selected year is still the same
- [ ] A category whose `Ergebnis` is positive is green with a leading `+`, a negative one red with `-`, legible under
      `Einstellungen` → theme `Dunkel` as well as `Hell`
