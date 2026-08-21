# Learn the merchant behind a collective payer (PayPal)

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Auto-Tagging |
| **Domain** | Transaction |
| **Blocked By** | None |
| **Status** | Draft |

## Description
Tagging learns and suggests on the **counterparty** only. For a collective payer that is useless: every PayPal payment carries
`PayPal Europe S.a.r.l.` as the counterparty while the actual merchant sits in the purpose text. One rule therefore covers dog
food, games, miniatures and groceries alike, and whichever category was assigned first gets suggested for all of them.

The user reports PayPal as frequent and spanning essentially every category. No other collective payer has shown up yet —
Klarna, credit-card settlements and collective direct debits have the same shape and can be added later if they appear.

## Prerequisite before any work starts
**The extraction pattern must be read off real statement lines, not guessed.** `ing_geometry_dump_test.dart` already dumps a
real statement env-gated; extend it (or add a sibling) to print the full purpose text of PayPal rows, then derive the rule from
what is actually printed. Ticket 033 showed what this is worth: five assumptions about a receipt layout fell the moment a real
document was measured, and the parser only works because it was built against the real thing.

Until that dump exists, this ticket stays Draft.

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

Costs a `kDbSchemaVersion` bump, which is cheap before release (`TransactionKind` in ticket 032 proved that) and needs
`make gen`.

## Open questions for refinement
- What exactly does the pattern look like, per the prerequisite above? Is it stable across PayPal payment types (purchase,
  subscription, refund)?
- Does the merchant show in the UI, and where — the booking list row currently shows the counterparty
- What happens on a **refund** through the same payer: same merchant, opposite sign?
- Should the extraction be part of `IngGiroParser` or a step after parsing, so a second bank inherits it? The purpose text is
  bank-independent in shape, the column it comes from is not
- Do rules learned on `PayPal Europe` before this lands need cleaning up? Ticket 025's rule list can delete them by hand, and
  the stale marker will not flag them because their categories are perfectly valid
- If a merchant is recognised, does the row still learn a counterparty rule as well — two rules per booking — or only the
  merchant one?

## Acceptance Criteria
_Not refined yet — the prerequisite dump comes first._

## Out of Scope (proposed, to confirm)
- Other collective payers until one actually appears
- Any change to the dedupe hash

## Affected Tests
- Extraction is pure text logic and belongs in unit tests over real-shaped purpose strings
- The tagging learn and suggest suites gain the `merchant ?? counterparty` key
- The env-gated harness proves the pattern against a real statement; no statement enters the repo

## Fixtures Needed
Ask during refinement. Purpose strings can be written inline once their real shape is known.

## Token Usage
_Filled after Done._
