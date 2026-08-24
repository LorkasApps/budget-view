# Adyen and Nexi hide their merchants in a different shape than PayPal

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Auto-Tagging |
| **Domain** | Transaction |
| **Blocked By** | None (047 shipped the seam) |
| **Status** | Draft |

## Description
Ticket 047 reads the merchant behind PayPal and left other collective payers out until one appeared. Two have:
`Adyen N.V.` and `Nexi Germany GmbH`. Their bookings carry the payment processor as counterparty, so tagging keys on the
processor and every shop paid through it shares one rule — the same defect 047 fixed for PayPal.

## Evidence already in hand
The January 2026 statement carries an Adyen row, and its purpose text has **nothing in common with PayPal's**:

```
Lastschrift Adyen N.V.
  Salon Pia Bruchmann/An der Hardt 1b /Knigswinter/DE 2026-01-09T18:47:58 Folgenr.000 Verfalld.2029-12
```

The merchant is the **leading segment before the first `/`**, followed by street, city, country and an ISO timestamp — the
card-terminal shape. `extractMerchant` looks for `/PP.####.PP/` and `Ihr Einkauf bei`, so it returns null here.

Worth noting: an ordinary card payment prints the same shape, and there the counterparty already *is* the merchant:

```
Lastschrift KAUFLAND
  Kaufland Bergisch Gladbach//Bergisc h Gladbach/DE 2025-12-30T17:34:09 F olgenr.000 Verfalld.2029-12
```

No Nexi line has been read yet. Its shape is **unknown** and must be dumped before any pattern is written — the same rule
047 followed, which is what turned up that PayPal prints its merchant twice.

## Open questions for refinement
- **Shape or whitelist?** A shape rule ("leading segment before `/`, followed by an address and an ISO timestamp") follows
  the house style (`decisions.md`, 2026-08-11 and 2026-08-21: derive from layout, never from a sender vocabulary) and would
  also fill `merchant` on ordinary card rows, where it changes nothing because the counterparty already names the shop. A
  whitelist of processor names is narrower but needs an entry per processor, forever
- Does Nexi print the same card-terminal shape, or a third one? Dump first
- The leading segment is also mid-word wrapped (`Bergisc h Gladbach`). Does the 047 trick apply — is the merchant printed
  twice here as well, or is there only the one spelling?
- Does the street belong in the merchant, or only the name? `Salon Pia Bruchmann` reads right; a branch suffix like
  `Kaufland Bergisch Gladbach` is arguably the better key than a bare `Kaufland`, but it splits one chain into per-branch rules
- Are the rules already learned on `Adyen N.V.` worth cleaning up, or does the dev wipe cover it as in 047?

## Acceptance Criteria
_Not refined yet — the Nexi dump comes first._

## Out of Scope (proposed, to confirm)
- Any change to the dedupe hash, as in 047
- Klarna, credit-card settlements and collective direct debits until one appears

## Affected Tests
- `merchant_extraction_test.dart` gains the acquirer shapes; its PayPal cases must stay green
- The env-gated harness in `test/tool/ing_geometry_dump_test.dart` proves the pattern against a real statement

## Fixtures Needed
No. Purpose strings inline, taken from real statement lines, as in 047.

## Token Usage
_Filled after Done._
