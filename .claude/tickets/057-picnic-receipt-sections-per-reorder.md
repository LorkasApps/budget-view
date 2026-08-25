# A receipt fragment without a printed total, judged against its booking

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | None |
| **Status** | Ready |

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

## Resolved during refinement
- **The booking amount becomes the bound, not the expectation.**
  As a bound it is right: nothing on a receipt costs more than the booking it belongs to, and it replaces exactly what a fragment
  loses with its printed total — in the case of 055 it would have thrown out `Betrag 67,07` even without an `Endsumme`.
  As an expectation for the mismatch banner it would be wrong: positions legitimately fall short while the user is still
  reviewing, and 019's Restposten exists because a partial itemisation is normal. A banner firing until the last row is typed is
  noise, and the figure already stands in `Σ … von …` at the bottom
- **No mismatch banner without a printed total** — today's behaviour (`expectedSumCents` null) is correct and stays
- **`Weiteren Bon scannen` (016) is the path for the next day** of the same order: same document, next booking, one pass each

## Acceptance Criteria
- [ ] A receipt fragment without a printed total imports its positions, with no mismatch banner
- [ ] When no printed total was read, the plausibility bound uses the **magnitude of the booking** the scan is attached to
- [ ] A row costing more than the booking is dropped, exactly as one costing more than a printed total is
- [ ] With a printed total present, nothing changes — it keeps precedence over the booking amount
- [ ] The booking amount reaches the parser without the parser learning about bookings: it is passed in, not looked up
- [ ] Two fragments of one order attach to two different bookings through `Weiteren Bon scannen`, each with its own bound
- [ ] `make check` green

## Out of Scope
- Parsing `Hinzugefügt am` sections out of one document; dropped with the reframe
- Cropping inside the app: the user crops before picking the image

## Affected Tests
- The parser suites for a fragment without a printed total, and whatever the bound becomes
- The scan flow tests if the booking amount has to reach the parser, which it does not today

## Fixtures Needed
No. A fragment without a total, built inline.

### Refinement Tokens (estimate)
- Input: ~9k tokens
- Output: ~2k tokens

### Implementation Tokens (estimate)
_Filled after Done._
