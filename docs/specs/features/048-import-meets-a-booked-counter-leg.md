# An import meets a counter-leg the app already booked

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Import |
| **Domain** | Transaction |
| **Blocked By** | 042 |
| **Status** | Done |

## Description
Split out of ticket 042, which writes the counter-leg of a transfer on the target account. That mirror booking can meet the
same movement a second time when the target account's own statement is imported later, and the normal duplicate guard will
not catch it: the dedupe hash keys on amount, booking day and normalized counterparty, and the imported row carries the
bank's own counterparty text rather than whatever the mirror booking wrote.

Scope of the collision, established on 2026-08-24: it needs **both** accounts to be importable. Today that is exactly one
pair, ING Girokonto ↔ Trade Republic Cashkonto. The common case, Giro → Tagesgeld, never sees a second import because ING
Extrakonten get no statements at all (ADR 0129). So this is a narrow but real case, not the general one.

## Resolved during refinement
- **It warns and the user decides**, with `Ersetzen` preselected and `Beide behalten` beside it. The match is a heuristic — the
  bank's text differs from what the app wrote — and this project already decided to ask rather than guess in exactly that
  situation (ADR 0043: intra-batch duplicates mark **both** copies, "the second is not automatically the wrong
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
- [x] Importing a row that matches an app-written mirror leg (same account, `kind == transfer`, carries `counterpartUuid`, same
      amount, booking date within ±5 days) raises a warning naming both dates and both texts. The link and `kind` filter run
      **before** any figure is compared, so an ordinary booking with identical figures is never offered (ADR 0150). The dialog
      uses `formatDateDe`, not the dense `formatDateCompactDe`: that one drops the year, and a ±5-day window can cross one
- [x] The warning offers `Ersetzen` (preselected) and `Beide behalten`. Preselected means emphasised **and** the default:
      dismissing the dialog leaves the replacement standing, which is what `keepBothLegRows` recording only the exception buys
- [x] `Ersetzen` writes the imported description, counterparty, amount and date onto the existing leg, keeps its category, note,
      `counterpartUuid` and `kind`, and creates no second booking. Also takes `merchant`, which is derived from the description
      that just changed — beyond the letter of this AC, and a no-op on a transfer, but leaving it would describe the wrong text
- [x] `Ersetzen` changes **nothing** on the other leg — no mirrored date, no mirrored amount. Free by construction: `persist`
      goes through `TransactionRepository.save` and never touches `TransferPairService.syncCounterpart`. Tested explicitly
- [x] `Beide behalten` imports the row as a normal booking, and both remain visible with their own dates
- [x] An imported row that matches **no** mirror leg behaves exactly as today, dedupe warning included
- [x] A mirror leg the user already replaced is not offered again on a re-import of the same statement (the document hash path of
      009 still applies). Follows from the layer ordering rather than from a rule of its own: the replaced leg carries the bank's
      fields, so it hashes like the row, and the mirror lookup only runs where the hash layer found nothing (ADR 0151)
- [x] `make check` green — 641 passed, 6 skipped, 0 failed (2026-09-22)

## Affected Tests
- `test/features/import/domain/duplicate_checker_test.dart` — group `mirror legs (ticket 048)`, seven tests: both window edges
  including a leg saved with a time of day, an unpaired transfer, a regular booking, a differing amount, a soft-deleted leg
- `test/features/transaction/import/pdf/pdf_dedupe_integration_test.dart` — group
  `mirror leg from a booked transfer (ticket 048)`, eight tests on a real Isar: the match itself, an ordinary booking with the
  same figures, the window, `Ersetzen`'s field-by-field result, the untouched other leg, `Beide behalten`, the replaced leg
  arriving as a plain duplicate, and an edit dropping the choice with the match
- `test/features/transaction/import/import_flow_widget_test.dart` — group `mirror leg (ticket 048)`, four tests: the dialog's
  two dates and two texts verbatim, both buttons, the absent duplicate marker, and dismissal leaving the replacement standing
- Eight existing fakes gained the new interface members: five `DuplicateChecker` stubs and three `TransactionRepository` ones
  (the latter surfaced only in the analyzer, since `TransactionRepository` is a concrete class the widget tests `implements`)

## Fixtures Needed
No. Two accounts, one mirror pair and one imported candidate, built inline.

### Refinement Tokens (estimate)
- Input: ~12k tokens
- Output: ~2k tokens

### Implementation Tokens (estimate)
_Filled after Done._
