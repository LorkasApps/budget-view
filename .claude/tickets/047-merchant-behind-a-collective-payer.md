# Learn the merchant behind a collective payer (PayPal)

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Auto-Tagging |
| **Domain** | Transaction |
| **Blocked By** | None |
| **Status** | Ready |

## Description
Tagging learns and suggests on the **counterparty** only. For a collective payer that is useless: every PayPal payment carries
`PayPal Europe S.a.r.l.` as the counterparty while the actual merchant sits in the purpose text. One rule therefore covers dog
food, games, miniatures and groceries alike, and whichever category was assigned first gets suggested for all of them.

The user reports PayPal as frequent and spanning essentially every category. No other collective payer has shown up yet —
Klarna, credit-card settlements and collective direct debits have the same shape and can be added later if they appear.

## First step inside the ticket (was: prerequisite before any work)
**The extraction pattern must be read off real statement lines, not guessed.** `ing_geometry_dump_test.dart` already dumps a
real statement env-gated; extend it (or add a sibling) to print the full purpose text of PayPal rows, then derive the rule from
what is actually printed. Ticket 033 showed what this is worth: five assumptions about a receipt layout fell the moment a real
document was measured, and the parser only works because it was built against the real thing.

Refined on 2026-08-24 with the pattern still open: the dump is the ticket's first step rather than its gate, since every other
question could be settled without it (user decision).

## Why not the obvious answers

**Suppressing the suggestion** — noticing that a counterparty carries many categories with similar hit counts, and offering the
alternatives sheet instead of a guess — was the first idea and is the wrong size here. It would be more honest but no more
useful: with PayPal spanning ten categories, a three-entry sheet is a lottery, and every payment would still be categorised by
hand.

**Overwriting `counterparty` with the merchant** looks cheapest and breaks something quiet: the dedupe hash is amount + date +
normalised counterparty. Tie it to a parser heuristic and a re-import after any parser change produces different hashes, so
bookings that already exist count as new. The duplicate protection would depend on a guess.

**Description-based rules** (`TaggingMatchField.description` exists unused) need different matching semantics — a purpose text
carries order numbers, so exact comparison never hits and substring matching has no index — and, worse, there is no way to
learn *which* substring mattered from one assignment. That would require hand-made rules, which ticket 025 deliberately ruled
out.

## Sketch to confirm during refinement
A separate field, e.g. `Transaction.merchant`, filled by the parser when it recognises a merchant inside the purpose text. The
learn and suggest paths key on `merchant ?? counterparty`. That keeps three things apart that today share one field:

| Field | Meaning |
|-------|---------|
| `counterparty` | literally what the statement says — identity, and what the dedupe hash is built from |
| `merchant` | who we believe it was — semantics, and the better tagging key |
| `description` | the purpose text the merchant was read out of |

Needs `make gen`. **Corrected during refinement:** it costs no `kDbSchemaVersion` bump. A new field is purely additive and
Isar returns its default for rows written before it existed — exactly how 032 introduced `Transaction.kind`
(`infrastructure.md`, Schema versioning).

## Resolved during refinement
- **The pattern stays open on purpose** → it is answered inside the ticket, as its first step, not before it. The dump comes
  first and the extraction rule is derived from what is printed (user decision, 2026-08-24)
- **UI** → the booking list row shows `merchant ?? counterparty`, because the row answers "who did I pay" and `Zooplus` is the
  right answer where `PayPal Europe S.a.r.l.` is the useless one. The booking **form** keeps showing the real counterparty: it
  is the booking's identity and the dedupe key, and must not disappear behind an interpretation. The **import preview** keeps
  it too — there you check what the bank wrote before it enters the app. List shows meaning, form and preview show fact
- **Refunds** → the extraction is sign-blind. The merchant is read from the purpose text whichever way the money runs, so a
  refund carries the same merchant and learns under the same key. Follows `decisions.md` (2026-08-10): free roots and the
  amount's sign carry direction, precisely so a repayment needs no second category. If PayPal writes refunds differently and
  no merchant is in the text, the row falls back to `counterparty` — a finding for the dump, not a design decision
- **Where extraction sits** → after parsing, as a pure function over **every** candidate, not inside `IngGiroParser`. The
  purpose text is bank-independent in shape, the column is not, so a second parser inherits it for free. Decisive detail:
  the field goes on `ParsedTransactionCandidate`, not only on `Transaction` at conversion time — otherwise the import preview
  never sees the merchant, and the preview is exactly where rows get categorised. `candidateToTransaction` then only copies
- **Old rules** → no migration and no manual cleanup. The dev data gets wiped anyway (`decisions.md`, 2026-08-10: nuke in dev,
  migrations from v1.0). Writing a one-shot cleanup that decides by heuristic which counterparty is "collective" would throw
  away curated data on a guess, and would be dead code after its single run
- **One rule per booking** → learn and suggest key on `merchant ?? counterparty`, so a recognised merchant learns only the
  merchant rule. Learning both would rebuild the lottery this ticket removes: the `PayPal Europe` rule would keep growing its
  `hitCount` across all merchants, would still be offered for every unrecognised row with an essentially random category, and
  the number would mislead in 025's rule list where `hitCount` is visible

## Acceptance Criteria
- [ ] **First step, before any field or parser code:** an env-gated harness prints the full purpose text of real PayPal rows
      (extending `ing_geometry_dump_test.dart` or a sibling next to it); no statement enters the repo
- [ ] The pattern derived from that dump is written into this ticket, including whether it holds across payment types
      (purchase, subscription, refund) — if it does not, the ticket says so before code follows
- [ ] `ParsedTransactionCandidate.merchant` and `Transaction.merchant` exist as nullable fields; `make gen` run, and
      `kDbSchemaVersion` **not** bumped (additive, as with `Transaction.kind` in 032)
- [ ] Extraction runs after parsing over every candidate, independent of which parser produced it; `candidateToTransaction`
      copies the value
- [ ] Learn and suggest key on `merchant ?? counterparty`, and a booking produces exactly **one** rule
- [ ] A refund through the same payer carries the same merchant as the purchase
- [ ] The booking list row shows `merchant ?? counterparty`; the booking form and the import preview still show the raw
      counterparty
- [ ] The dedupe hash is untouched — still amount + booking day + normalised `counterparty`, asserted as a regression guard
- [ ] A row whose purpose text yields no merchant behaves exactly as today
- [ ] `make check` green

## Out of Scope (proposed, to confirm)
- Other collective payers until one actually appears
- Any change to the dedupe hash

## Affected Tests
- Extraction is pure text logic and belongs in unit tests over real-shaped purpose strings
- The tagging learn and suggest suites gain the `merchant ?? counterparty` key
- The env-gated harness proves the pattern against a real statement; no statement enters the repo

## Fixtures Needed
No. Purpose strings are written inline once the dump has shown their real shape — the same call as every other parser ticket.

### Refinement Tokens (estimate)
- Input: ~17k tokens
- Output: ~3k tokens

### Implementation Tokens (estimate)
_Filled after Done._
