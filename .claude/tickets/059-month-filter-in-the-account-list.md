# Month filter in the account's booking list

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | None |
| **Domain** | Transaction |
| **Blocked By** | None (but see the note on 053) |
| **Status** | Draft |

## Description
The booking list shows every booking an account ever had. Wanted: a **month filter** — one month at a time, with the ability to
step through months the way the report does.

Besides being easier to read, this is the honest answer to a scale question that ticket 053 accepted as a cost: 053 filters in
memory over everything the account's stream delivers. A month filter is the natural boundary at which that stream could later
load one month instead of all of them, which turns "grows with the history" into "constant".

## Relation to 053
Both tickets build the same control row (search, category filter, and now the month). Designed separately, the row gets three
controls that do not know about each other; designed together, it is one filter surface. Refinement should decide whether this
blocks on 053 or is folded into it.

## Open questions for refinement
- **What is the default?** Current month, or all bookings as today? Defaulting to a month changes what the screen *is* — the
  balance header then sits above one month of rows, which is either a welcome focus or a permanent question mark
- **Which widget switches months?** The report uses the Material `DatePicker` and deliberately swallows the irrelevant day
  (`decisions.md`, 2026-08-20). Repeating that here repeats the compromise; a pair of arrows plus a month label is a different
  answer and needs no picker at all. "Durchwechseln wie beim Report" says stepping is wanted either way
- **Does the balance header change?** Ticket 053 decided the header stays the *account's* balance and gets no filtered sum,
  because it is a balance and not a list total. With a month filter that tension is sharper: a month of rows under an all-time
  balance invites the reading "this is the month's balance". Options: leave it and trust the label, add the month's sum as a
  second line after all, or show the balance *as of the end of that month*, which is a third figure and a real feature
- Does the month filter combine with search and category (AND), and does search then only look inside the month? Searching for
  a booking one does not know the date of is the case where a month filter gets in the way
- Does the chosen month survive a tab switch and a return to the account, like the report's filters do?
- What does a month without bookings show, and can one step past the newest month into an empty future?

## Acceptance Criteria
_Not refined yet._

## Out of Scope (proposed, to confirm)
- A date-range filter; this is one calendar month at a time
- Loading only the selected month from Isar — worth its own ticket if the in-memory filtering of 053 ever hurts

## Affected Tests
- The booking-list tests: the default view, stepping months, an empty month, and the combination with search and category

## Fixtures Needed
Ask during refinement.

## Token Usage
_Filled after Done._
