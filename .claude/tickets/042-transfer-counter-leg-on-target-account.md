# A transfer names its target account and books the counter-leg there

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | None |
| **Domain** | Transaction |
| **Blocked By** | 032 |
| **Status** | Draft |

## Description
A transfer is marked per booking today: the leg on the account being looked at is flagged, and the report leaves it out.
What is missing is the other side. Money that leaves the Giro account arrives on the Tagesgeld account, and the app cannot
say so — the receiving balance only learns about it when that account's own statement is imported, which may be weeks
later or never for an account that is not imported at all.

Wanted: when marking a booking as a transfer, name the account on the other side, and let the app book the counter-leg
there — same amount with the opposite sign, same date.

## Why this is more than a second save
Ticket 032 deliberately left the two legs unlinked. Writing the mirror booking creates the problem it avoided: the same
movement can now enter the database twice — once because this feature wrote it, once because the other account's statement
gets imported later. The dedupe check keys on amount, booking day and normalized counterparty; the imported leg will carry
the bank's own counterparty text, which almost certainly differs from whatever the mirror booking wrote. So the guard that
normally catches a double booking is exactly the one that will not fire here.

That collision is the ticket. The picker for the target account is the easy half.

## Open questions for refinement
- **How is the pair recognised later?** A stored link (a `counterpartUuid` field, hence a schema addition), or matching on
  amount, date and the two account uuids at read time?
- **What does the import do when it meets the already-booked counter-leg?** Recognise and merge it into the existing
  booking, warn like a duplicate and let the user decide, or nothing — and then the receiving account is wrong by one
  movement, silently
- **What happens on edit and delete?** Changing the amount of one leg must not leave the pair inconsistent, and deleting one
  leg should presumably take the other with it — which is the first cascading delete in this app
- **Which accounts may be chosen?** Every other own account, including archived ones? A transfer to an account that does not
  exist in the app is a legitimate case too (a broker outside the app), and then no counter-leg can be written
- **Does the target account's category matter?** The counter-leg needs none — it is a transfer as well — but it does need a
  description, and "Übertrag von Giro" is the app inventing text on the user's behalf
- Scope check: the picker plus the counter-leg plus the import reconciliation may be more than one ticket

## Acceptance Criteria
_Not refined yet — the questions above come first._

## Out of Scope (proposed, to confirm)
- Multi-currency transfers
- Transfers between accounts of different users

## Affected Tests
Unknown until the recognition question is answered. The dedupe suites and the balance suites are the ones most likely to
change, and the import flow gains a case it has never seen.

## Fixtures Needed
Ask during refinement.

## Token Usage
_Filled after Done._
