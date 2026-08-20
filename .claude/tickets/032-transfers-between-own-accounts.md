# Transfers between own accounts are counted as spending

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | None |
| **Domain** | Transaction |
| **Blocked By** | None |
| **Status** | Draft |

## Description
A booking carries an amount and a sign, nothing else. Moving money from one own account to another therefore looks
exactly like buying something: the outgoing leg is an expense, and once the receiving account is imported too, the
incoming leg is income. Both legs land in the monthly report, and both totals grow by an amount that never left the
user's own money.

Found during the ticket 028 device pass, not by a failing test — the numbers are internally consistent, which is why
nothing flagged it:

| Value | Amount |
|-------|--------|
| Report `Ausgaben`, July, ING | 12.891,34 |
| Report `Einnahmen`, July, ING | 12.423,98 |
| Net (reconciles with `Neuer Saldo − Alter Saldo`) | −467,36 |

The user's own estimate of real spending was around 3k. The gap is transfers — savings moves and a transfer to another
account. So the report is arithmetically right and factually misleading, which is worse than a wrong sum: it is a number
you would act on.

## Why this is not a report bug
The rollup sums what the data says. The missing piece sits one layer down: `Transaction` has no notion of a booking whose
counterpart is another account of the same user. Fixing it in the report alone would mean guessing there.

## Open questions for refinement
- **How is a transfer recognised?** A flag the user sets on a booking, a pairing of two bookings across accounts (same
  amount, opposite sign, near-identical date), a rule on the counterparty text, or the target-account field an import
  could offer? Each has a different failure mode — pairing invents links, a manual flag needs discipline, counterparty
  text is a heuristic on bank wording
- **One booking or two?** A transfer is physically two bookings, one per account. Does the model keep both and link
  them, or does it grow a first-class `Transfer` that owns both legs? The second is cleaner and touches far more code
- **What if only one side is imported?** Today the ING statement is the only source. The outgoing leg exists, the
  receiving account may not even be in the app
- **Where does it have to take effect** beyond the monthly report — forecast (021), price trends (022) are line-item
  based so probably not, category suggestions (014) would otherwise learn rules from transfers
- **Does this need a new field on `Transaction`?** That means a `kDbSchemaVersion` bump and, per `docs/sync.md`, a
  decision on how it mirrors to the change queue
- **What happens to the bookings already imported?** Nothing marks them today; is a one-off pass over existing data
  wanted, or does the feature only apply going forward?
- Scope check during refinement: recognition, model change and report exclusion may well be more than one ticket — the
  013 → 025 and 009 → 024 splits are the precedent

## Acceptance Criteria
_Not refined yet — the questions above come first._

## Out of Scope (proposed, to confirm)
- Multi-currency
- Anything about the receiving account's own categorisation

## Affected Tests
Unknown until the recognition question is answered. The report rollup suites are the ones most likely to change.

## Fixtures Needed
Ask during refinement.

## Token Usage
_Filled after Done._
