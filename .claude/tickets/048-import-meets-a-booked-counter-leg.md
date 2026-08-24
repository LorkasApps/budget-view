# An import meets a counter-leg the app already booked

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Import |
| **Domain** | Transaction |
| **Blocked By** | 042 |
| **Status** | Draft |

## Description
Split out of ticket 042, which writes the counter-leg of a transfer on the target account. That mirror booking can meet the
same movement a second time when the target account's own statement is imported later, and the normal duplicate guard will
not catch it: the dedupe hash keys on amount, booking day and normalized counterparty, and the imported row carries the
bank's own counterparty text rather than whatever the mirror booking wrote.

Scope of the collision, established on 2026-08-24: it needs **both** accounts to be importable. Today that is exactly one
pair, ING Girokonto ↔ Trade Republic Cashkonto. The common case, Giro → Tagesgeld, never sees a second import because ING
Extrakonten get no statements at all (`decisions.md`, same date). So this is a narrow but real case, not the general one.

## Open questions for refinement
- Does the import **recognise** the mirror booking and merge into it, **warn** like a duplicate and let the user decide, or
  do nothing — leaving the account wrong by one movement, silently?
- What identifies the pair at import time: the link 042 stores, or amount + day + the two account uuids?
- Does an accepted merge keep the mirror booking's own text or the bank's, and which side wins on a conflict?
- Intra-batch: what if one imported file contains both legs (possible once two accounts are imported from one bank)?

## Acceptance Criteria
_Not refined yet — the questions above come first._

## Affected Tests
Likely the dedupe suites and `pdf_dedupe_integration_test.dart`, plus the import preview around the duplicate warning.

## Fixtures Needed
Ask during refinement.

## Token Usage
_Filled after Done._
