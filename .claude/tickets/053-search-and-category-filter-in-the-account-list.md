# Word search and a category filter in the account's booking list

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | None |
| **Domain** | Transaction |
| **Blocked By** | None |
| **Status** | Draft |

## Description
The booking list of an account offers exactly one way to narrow itself down today: the `Nur ohne Kategorie` toggle. Finding a
specific booking means scrolling. Wanted: a **word search** and a **category filter**.

## Precedents that should decide the details
- **Search semantics are already settled once.** Ticket 038 gave the category picker a case-insensitive substring search and
  deliberately rejected `normalizeForMatching`, because that function exists for machine comparison in dedupe and tagging and
  widening it would silently change what search does. Umlauts stay literal there, so `Bruehe` does not find `Brühe` — a second
  search in the same app should behave the same way or the app has two answers to one question
- **A category filter is a subtree question, not a row question.** The report drills into a category *including* its children
  (`decisions.md`, 2026-08-18). Picking `Lebensmittel` in a list filter and not seeing the `Getränke` bookings would read as a
  bug, and ticket 051 (one sub-level only) does not change that, it just bounds the depth
- **The merchant is now visible in the row** (ticket 047): the list shows `merchant ?? counterparty`, so search has to cover
  what the user sees, not only what the bank wrote
- **Ticket 049** is about transfers clogging the existing uncategorized filter. If this ticket rebuilds the filter row, the two
  overlap — 049 may end up folded in here or become redundant

## Open questions for refinement
- **Which fields does the search cover?** Description, counterparty, merchant, note — and does the amount count, so typing
  `12,50` finds a booking?
- **Does the category filter replace the `Nur ohne Kategorie` toggle**, with "Ohne Kategorie" as one of its options? That
  consolidates two controls into one and is where 049's rule would live
- Single category or several at once?
- Do search and filter combine (AND), and does the sum line at the bottom then show the filtered total or the account's?
- **Where does the filtering happen** — in a repository query or in memory over the account's already-streamed bookings? The
  second is simpler and honest for a phone-sized list, but the list grows with every import
- Does the search field survive a tab switch, like the report's filters do (the `IndexedStack` keeps state on purpose)?
- What does the empty result say, and does clearing both controls restore the full list in one gesture?

## Acceptance Criteria
_Not refined yet._

## Out of Scope (proposed, to confirm)
- Searching across accounts — this is the per-account overview
- Filtering by date range or amount range; that is a different ticket if it is wanted at all

## Affected Tests
- The booking-list widget tests: search narrows, filter narrows, both together, and the existing uncategorized behaviour
  (whatever it becomes) keeps holding

## Fixtures Needed
Ask during refinement.

## Token Usage
_Filled after Done._
