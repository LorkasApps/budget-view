# Transfers between own accounts are counted as spending

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | None |
| **Domain** | Transaction |
| **Blocked By** | 037 (both extend the import preview edit dialog) |
| **Status** | Done |

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

## Resolved during refinement
- **Recognition** → the user marks a booking as a transfer. No heuristic that can be wrong, and it works when only one side
  of the pair is imported, which is today's situation. Rejected automatic pairing (it invents links: two equal amounts on
  one day are not a transfer, and with a single imported account it finds nothing) and rejected a counterparty rule (bank
  wording is inconsistent, and a rule firing wrongly would *hide* real spending — an invisible error instead of a visible
  one)
- **Storage** → a new `TransactionKind` field (`regular` | `transfer`), stored by name like `TaggingMatchField`. Chosen over
  a `bool isTransfer` because 040 brings the same class of case (a securities purchase is money changing form, not leaving),
  and a two-value bool would be renamed within weeks. Costs a `kDbSchemaVersion` bump plus a sync-payload key — cheap now,
  since nothing is released and dev bumps nuke and rebuild
- **Consequences** → for `transfer` the category requirement drops (a transfer belongs in no spending category) while a
  category stays allowed; the learn hook skips transfers, so no rule is created that would later suggest a spending category
  for one. The exclusion itself happens centrally in the rollup, which is what makes the forecast inherit it for free
- **Where it is set** → in the booking form **and** in the import preview's edit dialog — the dialog that 037 is extending
  with the category. Import time is when you still know that a row is a transfer. This ticket therefore comes after 037, so
  the second change does not land in a dialog someone else is rewriting
- **Existing data** → no bulk assistant. The few transfers among the already imported bookings get marked by opening them;
  a bulk tool would need candidate detection, which is the pairing heuristic this ticket rejected
- **Fixtures** → none; the rollup tests build their bookings inline as they do today

## Acceptance Criteria
- [x] `Transaction` gains `kind` (`TransactionKind.regular` | `.transfer`), stored by name, default `regular`
- [x] `kDbSchemaVersion` is bumped and the sync payload carries the new key
- [x] The booking form has a transfer toggle; the import preview's edit dialog has the same toggle writing the same field
- [x] With `transfer` set, the category is no longer required — saving without one works, and setting one is still allowed
- [x] `TaggingLearnService` skips transfers: marking one and saving creates no rule and raises no `hitCount`
- [x] The monthly report rollup excludes transfers from **both** `Ausgaben` and `Einnahmen`, and the `Ohne Kategorie` row
      does not collect them either
- [x] The forecast inherits the exclusion because it reads the same rollup — covered by a test rather than by assumption
- [x] Account balances still include transfers: the money did move, so a balance without them would be wrong
- [x] Tests: rollup with and without a transfer, the learn hook skipping one, the relaxed category requirement, and the
      balance still counting it
- [x] `make check` green
- [x] The report numbers of the 028 finding become reproducible: with the transfers of the imported statement marked,
      `Ausgaben` drops to the order the user expected. Verified on the device against the existing data — no re-import was
      needed, since the added field is additive and old rows read back as `regular`

## Out of Scope
- Multi-currency
- Anything about the receiving account's own categorisation
- Linking the two legs of a transfer to each other; the marking is per booking
- A bulk assistant for existing data

## Affected Tests
- `monthly_category_report_service_test.dart` and the forecast suite — the exclusion
- The tagging learn suite — transfers must not teach
- Transaction validation and form tests — the conditional category requirement
- The balance suite — transfers still count

## Fixtures Needed
No — inline bookings, as the report suites do today.

### Refinement Tokens (estimate)
- Input: ~18k tokens
- Output: ~3k tokens

### Implementation Tokens (estimate)
- Input: ~55k tokens
- Output: ~6k tokens

## Outcome
452 tests pass (10 new). One belief did not survive contact: the schema bump does **not** wipe the dev database. Reconcile
only records the new version, so the existing 77 bookings stayed and read back as `regular` — which is the wanted meaning
anyway. `infrastructure.md` said "dev = nuke+rebuild on bump" and has been corrected.

Two follow-ups came out of the device check: the category field still renders its red required hint for a transfer even
though saving works (ticket 041), and a transfer cannot yet name the account on the other side so the counter-leg gets
booked there (ticket 042).
