# Suggest a category per scanned position

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Auto-Tagging |
| **Domain** | Tagging |
| **Blocked By** | None (see the note on 055) |
| **Status** | Draft |

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

## Open questions for refinement
- Where does the suggestion appear in the review row — as a filled chip like the import preview does, with a marker and its
  count, or only as an offer the user taps?
- Does it apply automatically to every matching row on arrival, like the import preview fills rows, or does nothing move until
  the user acts? Thirty rows silently pre-filled is a lot of trust in one heuristic
- Does an accepted per-position suggestion count as a hit for the article rule, and does an override raise the new category the
  way the booking side does?
- Does `alle kategorisieren` still override everything, including suggested rows?
- Do positions of a **PDF** receipt (033/044) get the same treatment? Same data shape, so presumably yes
- Does the line-item sheet outside the scan flow suggest too, or is this scan-only?

## Acceptance Criteria
_Not refined yet._

## Out of Scope (proposed, to confirm)
- Learning from the booking's own category onto its positions; that is inheritance and already exists
- Any change to the dedupe hash or to price-trend grouping

## Affected Tests
- The tagging learn and suggest suites gain the description field, including that a counterparty rule and an article rule with
  the same text stay apart
- Review-screen tests for the suggestion, and the line-item sheet tests if it is included

## Fixtures Needed
Ask during refinement.

## Token Usage
_Filled after Done._
