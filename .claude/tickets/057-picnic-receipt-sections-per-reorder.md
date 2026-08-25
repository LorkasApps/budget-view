# A receipt fragment without a printed total, judged against its booking

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | None |
| **Status** | Draft |

## Description
A Picnic order can be added to after it was placed, and the receipt then carries a `Hinzugefügt am <dd MMMM>` heading above the
items that came later. Each part is charged separately, so one receipt describes several bookings.

**Reframed on 2026-08-25**, after the attempt to capture such a receipt: it is far too long for one screenshot. Parsing sections
out of one document is therefore the wrong answer to the wrong problem — the user crops **per day** instead and scans the part
that belongs to the booking at hand.

That turns the ticket into something much smaller, and shifts it: a fragment carries **no printed total**, because the total
belongs to the whole order and sits at the very bottom. So the only figure to judge the positions against is the **booking** the
scan is attached to.

Section parsing is dropped. `Hinzugefügt am` stays interesting only as the visual hint that tells the user where to cut.

## What already works, and what does not
- **The review screen already shows the booking**: `Σ <kept> von <booking amount>`, and 019's Restposten closes whatever gap
  remains at confirm. A fragment without a total therefore imports fine today — `expectedSumCents` is null, so no mismatch banner
  appears, which is correct rather than broken
- **What is lost with the total is the plausibility bound.** `exceedsPositionBudget` needs a budget, and without one every row
  that looks like money stays — the case ticket 055 shows with `Betrag` and `Gespart` from the summary block. On a fragment, a
  header or footer fragment has nothing bounding it at all

## The open question
Does the booking amount become the **bound**, the **expectation**, or both?

- As a **bound** it is right: nothing on a receipt costs more than the booking it belongs to
- As an **expectation** for the mismatch banner it is wrong: positions legitimately fall short while the user is still reviewing,
  and 019's Restposten exists precisely because a partial itemisation is normal. A banner that fires until the last item is typed
  would be noise, and the sum is already visible in `Σ … von …`

## Open questions for refinement
- The bound-versus-expectation split above
- Does the bound use the booking's magnitude as-is, or leave headroom for a discount row printed above the item?
- Does anything need to change at all, or is this only the bound? The fragment case may otherwise be covered already
- Is `Weiteren Bon scannen` (016) the intended path for the second day of the same order — same document, next booking?

## Acceptance Criteria
_Not refined yet — one question open._

## Out of Scope
- Parsing `Hinzugefügt am` sections out of one document; dropped with the reframe
- Cropping inside the app: the user crops before picking the image

## Affected Tests
- The parser suites for a fragment without a printed total, and whatever the bound becomes
- The scan flow tests if the booking amount has to reach the parser, which it does not today

## Fixtures Needed
No. A fragment without a total, built inline.

## Token Usage
_Filled after Done._
