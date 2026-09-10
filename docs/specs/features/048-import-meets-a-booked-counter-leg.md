# An import meets a counter-leg the app already booked

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Import |
| **Domain** | Transaction |
| **Blocked By** | 042 |
| **Status** | Ready |

## Description
Split out of ticket 042, which writes the counter-leg of a transfer on the target account. That mirror booking can meet the
same movement a second time when the target account's own statement is imported later, and the normal duplicate guard will
not catch it: the dedupe hash keys on amount, booking day and normalized counterparty, and the imported row carries the
bank's own counterparty text rather than whatever the mirror booking wrote.

Scope of the collision, established on 2026-08-24: it needs **both** accounts to be importable. Today that is exactly one
pair, ING Girokonto ↔ Trade Republic Cashkonto. The common case, Giro → Tagesgeld, never sees a second import because ING
Extrakonten get no statements at all (`decisions.md`, same date). So this is a narrow but real case, not the general one.

## Resolved during refinement
- **It warns and the user decides**, with `Ersetzen` preselected and `Beide behalten` beside it. The match is a heuristic — the
  bank's text differs from what the app wrote — and this project already decided to ask rather than guess in exactly that
  situation (`decisions.md`, 2026-08-12: intra-batch duplicates mark **both** copies, "the second is not automatically the wrong
  one"). `Ersetzen` is the default because the imported row is bank-confirmed while the mirror carries only
  `Umbuchung von <Konto>`, and double-counting a movement is worse than losing a generated helper text. Doing nothing was
  rejected outright: an account that counts one movement twice is the defect 032 and 042 exist to prevent
- **Identification uses the link *and* the figures.** The `counterpartUuid` from 042 plus `kind == transfer` narrows the
  candidates to bookings the app wrote as a mirror — every ordinary booking is out before any comparison. Within that small set,
  amount and date on the same account pick the row. The dedupe hash is unusable here: it contains the counterparty, and the bank
  writes a different one.
  **Date window ±5 days, with both dates named in the warning.** The app writes the mirror with the source leg's date while the
  receiving bank often books a day or two later, so exact-day matching would quietly find nothing. Since the user confirms
  anyway, a generous window with a visible difference is safer than a narrow one
- **`Ersetzen` takes the bank's fields, keeps the user's.** Description, counterparty, amount and date come from the imported
  row — those are the bank's facts for this account. Category and note stay, as does the structure (`counterpartUuid`,
  `kind == transfer`)
- **This path does not propagate to the other leg**, which is a correction to 042: its mirroring of amount and date is a rule for
  **form edits**. The money leaves on one day and arrives on another, so writing the receiving leg's real date must not overwrite
  the sending leg's. Same for the amount: if the legs differ (a fee), the bank is the truth per leg and the difference stays
  visible in both instead of being averaged away. 042 carries a note about this
- **Intra-batch is out of scope.** Both parsers read statements that describe exactly one account, so one file cannot contain
  both legs today. If a multi-account statement ever appears, the existing intra-batch rule already has the right shape

## Acceptance Criteria
- [ ] Importing a row that matches an app-written mirror leg (same account, `kind == transfer`, carries `counterpartUuid`, same
      amount, booking date within ±5 days) raises a warning naming both dates and both texts
- [ ] The warning offers `Ersetzen` (preselected) and `Beide behalten`
- [ ] `Ersetzen` writes the imported description, counterparty, amount and date onto the existing leg, keeps its category, note,
      `counterpartUuid` and `kind`, and creates no second booking
- [ ] `Ersetzen` changes **nothing** on the other leg — no mirrored date, no mirrored amount
- [ ] `Beide behalten` imports the row as a normal booking, and both remain visible with their own dates
- [ ] An imported row that matches **no** mirror leg behaves exactly as today, dedupe warning included
- [ ] A mirror leg the user already replaced is not offered again on a re-import of the same statement (the document hash path of
      009 still applies)
- [ ] `make check` green

## Affected Tests
Likely the dedupe suites and `pdf_dedupe_integration_test.dart`, plus the import preview around the duplicate warning.

## Fixtures Needed
No. Two accounts, one mirror pair and one imported candidate, built inline.

### Refinement Tokens (estimate)
- Input: ~12k tokens
- Output: ~2k tokens

### Implementation Tokens (estimate)
_Filled after Done._
