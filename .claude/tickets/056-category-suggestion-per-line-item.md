# Suggest a category per scanned position

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Auto-Tagging |
| **Domain** | Tagging |
| **Blocked By** | 055 (article names must read correctly first) |
| **Status** | Ready |

Secondary domain: Drilldown — the suggestion is shown in the scan review screen and the line-item sheet, both of which live
there.

## Description
Tagging learns from bookings only (`tagging.md`: "Learning from line-item level assignments — MVP learns from bookings only").
A scanned receipt therefore arrives with thirty uncategorised positions, and the only tools are one category for all of them
(`alle kategorisieren`) or thirty taps. Wanted: a suggestion **per position**, shown while the scan result is on screen.

## What already fits
- **The key exists.** `normalizeForMatching(description)` is what ticket 022 groups price trends by, so `h-milch 1,5 %` is
  already a stable article term in this app. Using the same function keeps "the same article" meaning one thing in three places
  (dedupe, tagging, trends)
- **The field exists.** `TaggingMatchField.description` sits in the rule entity and is read nowhere. This is what it was for
- **The call-site rule exists.** Learning is triggered by the UI paths that assign a category, never by a repository hook
  (`decisions.md`, 2026-08-13) — so the review screen's confirm and the line-item sheet's save are the natural places

## The traps to resolve
- **`matchField` must enter the lookup.** Rules for counterparties and rules for article descriptions would otherwise share one
  key space, and `Milch` the shop would collide with `Milch` the article. Every existing query goes through
  `findByCounterparty`, which does not filter by field today
- **Inheritance versus a written category.** A position with a null category inherits the booking's (ticket 012). An accepted
  suggestion writes a category and thereby leaves inheritance behind — silently, unless it says so. Transactions carry
  `categoryAutoSuggested` so an accepted guess cannot reinforce itself; `LineItem` has no such flag, and adding one is a schema
  question (additive, so no bump — the 032 precedent)
- **The rule list of 025** would start showing article rules next to counterparty rules. `h-milch 1,5 %` beside `REWE Berlin` in
  one list needs at least a distinction, and 025's rule stands: rules are curated, never hand-created
- **Value depends on 055.** A suggestion keyed on the description is only as good as the description, and a photographed receipt
  currently reads badly. Building this on top of wrong article names would teach wrong rules that then have to be curated away.
  Refinement should decide whether this blocks on 055 or ships behind it

## Resolved during refinement
- **Blocked by 055.** The key is the article description, and the photo path currently reads descriptions badly. What that
  produces is not merely poor suggestions but **stored rules on wrong names**, and 025 deliberately has no bulk cleanup — the
  mistake would write itself into data instead of passing
- **Rows are filled automatically**, with the marker and hit count of the import preview — at thirty positions a suggestion one
  has to tap per row halves the work instead of doing it. But **only when the rule is unambiguous**: exactly one candidate
  category, or a strongest one with a strictly higher `hitCount` than the next. Otherwise the row stays empty and the marker
  only offers the alternatives
- **No persisted flag on `LineItem`.** Learning happens at `Übernehmen`, from the candidates, which are still in memory — a
  transient `categorySuggested` on `LineItemCandidate`, mirroring `ImportRow`, is enough to skip the machine's own guesses. The
  booking side needs a stored flag because a booking is edited later by paths that do not know its history; a position's only
  other write path is the line-item sheet, where every change is by hand and therefore teaches
- **`alle kategorisieren` overrides everything**, suggested rows included: it is an explicit bulk action and already touches
  only kept rows
- **PDF positions behave identically** — both parsers hand over the same candidate shape
- **The line-item sheet outside the scan flow suggests too**; it is the same question about the same article
- **The rules screen keeps one list with a switch by kind** (`Empfänger` / `Artikel`). Both kinds need the same curating, a
  second settings entry would bloat the menu, and doing nothing would drown the handful of counterparty rules under hundreds of
  article rules — devaluing the surface 025 just built

## Acceptance Criteria
- [ ] Setting a position's category by hand writes a rule with `matchField = description` and
      `normalizeForMatching(description)` as its key — from the review's confirm and from the line-item sheet
- [ ] The rule lookup is field-aware: a counterparty rule and an article rule with the same text never match each other
- [ ] On arrival in the review, a position with an unambiguous rule is pre-filled and marked with its hit count
- [ ] A position whose rules tie (equal `hitCount` at the top) is **not** pre-filled; the marker offers the alternatives
- [ ] A pre-filled row that the user leaves alone teaches nothing on confirm; overriding it raises the chosen category
- [ ] `alle kategorisieren` overrides suggested and hand-set rows alike
- [ ] Positions from a PDF receipt behave the same as from a photo
- [ ] The line-item sheet suggests outside the scan flow as well
- [ ] `TaggingRulesScreen` switches between `Empfänger` and `Artikel` rules, and curating either still works
- [ ] No schema change, no `kDbSchemaVersion` bump, nothing about the dedupe hash or price-trend grouping
- [ ] `make check` green

## Out of Scope (proposed, to confirm)
- Learning from the booking's own category onto its positions; that is inheritance and already exists
- Any change to the dedupe hash or to price-trend grouping

## Affected Tests
- The tagging learn and suggest suites gain the description field, including that a counterparty rule and an article rule with
  the same text stay apart
- Review-screen tests for the suggestion, and the line-item sheet tests if it is included

## Fixtures Needed
Ask during refinement.

### Refinement Tokens (estimate)
- Input: ~16k tokens
- Output: ~3k tokens

### Implementation Tokens (estimate)
_Filled after Done._
