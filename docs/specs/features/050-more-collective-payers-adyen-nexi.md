# Adyen and Nexi hide their merchants in a different shape than PayPal

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Auto-Tagging |
| **Domain** | Transaction |
| **Blocked By** | None (047 shipped the seam) |
| **Status** | Done |

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

_Superseded by the next section: the dump ran on 2026-09-10 and Nexi's shape turned out to be a third one. The paragraph above
is kept because it is the reason the pattern was not written from the Adyen row alone._

## Dump finding, 2026-09-10
The harness case now prints a probed payer even when `extractMerchant` returns null — that null is the finding. Run against
the September 2026 statement: 74 rows, 13 with a merchant, **5 probed payers without one**.

**Adyen prints the shape the ticket assumed.** Four rows over three merchants, with two dents in the text layer:

| Purpose text, leading part | Leading segment | Dent |
|---|---|---|
| `Salon Pia Bruchmann/An der Hardt 1b /Knigswinter/DE …` | `Salon Pia Bruchmann` | none |
| `BootshausRadolfzell/Schlossstrae 12 /Gaienhofen/DE …` | `BootshausRadolfzell` | space swallowed between the two words |
| `LS Akropolis Grill Loh/Hauptstrae 8 9/Lohmar/DE …` | `LS Akropolis Grill Loh` | **`LS ` prefix**, and the name is cut mid-word |

The `LS ` prefix is new information — it is on none of the rows the ticket was filed with, so the leading segment needs it
stripped before it becomes a key.

**Nexi prints a third shape**, which answers the question AC 1 asked. One row:

```
BAECKEREI SCHMIDT E K INHA 301 Refr GIR 79998979//BERGISCH GLADBAC/DE 2026-08-12T09:37:33 Folgenr.001 Verfalld.2029-12
```

The leading segment is the merchant *plus noise*: legal form (`E K INHA`), what looks like a terminal number (`301`), and a
reference (`Refr GIR 79998979`). The street segment is empty, hence the `//` — not Nexi-specific, the `KAUFLAND` row in the
section above prints `//` too. So the plain leading-segment rule of AC 4 holds for Adyen and **fails for Nexi**.

**Decision, 2026-09-10: cut the segment at `Refr`.** The reference number is assumed to vary per booking, which would make
the raw segment a per-purchase key and reproduce exactly the rule-explosion the whitelist was chosen to avoid. Only one Nexi
row exists, so the assumption cannot be verified — cutting is correct whether it varies or not, which is why it beats waiting
for a second statement.

The cut yields `BAECKEREI SCHMIDT E K INHA 301`. Legal form and the `301` stay in: unlike the reference, a terminal number
plausibly belongs to the store rather than the booking, and dropping it would need a second assumption on top of the first.
Accepted — a key does not need to be presentable, only stable.

## Resolved during refinement
- **A whitelist of payer names, not a shape rule** — and this reverses the lean the ticket was filed with. The card-terminal
  shape is also printed by **ordinary** card payments, where the counterparty already names the shop (`Lastschrift KAUFLAND` with
  `Kaufland Bergisch Gladbach//…`). A shape rule would set `merchant` there too, and since `taggingKey` prefers the merchant, one
  `kaufland` rule would become one rule **per branch** — a doubling of rules for rows that work today. The shape does not say
  that a counterparty is a proxy; only the name does. Accepted cost: one entry per processor, extended by hand in code, which is
  at least visible in one place instead of hidden in a heuristic
- **The merchant is the leading segment before the first `/`**, trimmed. For Adyen that is `Salon Pia Bruchmann`
- **PayPal keeps its own path**, keyed on its `/PP.####.PP/` marker rather than on the list
- **Nexi's shape is still unknown** and is dumped before the pattern is written — the rule that turned up three wrong
  assumptions in 040 and the twice-printed merchant in 047
- **No cleanup of rules already learned on `Adyen N.V.`**: the dev data gets wiped anyway (`decisions.md`, 2026-08-10), same as
  in 047
- **Accepted limit:** the text layer drops characters — the real Adyen row reads `Knigswinter`, missing the `ö` of
  Königswinter. A merchant name from this shape is therefore occasionally incomplete, and nothing on our side can recover it.
  It stays a stable *key* regardless, which is what tagging needs

## Acceptance Criteria
- [x] **First step:** the env-gated harness prints the purpose text of every row whose counterparty is a listed payer, whether or
      not a merchant was extracted, and the rule is derived from the real Adyen and Nexi rows
- [x] The finding is written into this ticket, including whether Nexi shares Adyen's shape or prints a third one
- [x] A `const` set of collective payers lives beside `extractMerchant`, compared through `normalizeForMatching` with a
      `startsWith`, so casing and spacing variants of a name still hit
- [x] For a listed payer, the merchant is the leading segment before the first `/`
- [x] A leading `LS ` is stripped from that segment — the Akropolis row prints it, so without the strip the same shop keys
      differently depending on which prefix the statement happened to print
- [x] The segment is cut at `Refr` and re-trimmed, so Nexi's per-booking reference cannot leak into the key. `BAECKEREI
      SCHMIDT E K INHA 301 Refr GIR 79998979` becomes `BAECKEREI SCHMIDT E K INHA 301`
- [x] For an **unlisted** counterparty nothing changes — a `KAUFLAND` row keeps its single rule, with no branch in the key
- [x] A listed payer whose purpose text yields nothing falls back to the counterparty, as PayPal's empty row already does
- [x] PayPal rows behave exactly as they do today; the 047 test cases stay green
- [x] Nothing about the dedupe hash changes
- [x] `make check` green

## Out of Scope
- Any change to the dedupe hash, as in 047. Verified rather than assumed: `dedupe_hash.dart` hashes amount, booking day and
  the normalised **counterparty**, never the merchant, and the file was not touched
- Klarna, credit-card settlements and collective direct debits until one appears

## Open, deliberately not a ticket
The `Refr` cut rests on **one** Nexi row. Should a second statement with a Nexi booking ever turn up, the assumption becomes
checkable in one run of the harness: a different number in `Refr GIR …` proves the cut right, an identical one means the key
could have been longer. Not worth a ticket — the cut is correct either way, this is only the cheaper key left on the table.

## Affected Tests
- `merchant_extraction_test.dart` gains the acquirer shapes; its PayPal cases must stay green
- The env-gated harness in `test/tool/ing_geometry_dump_test.dart` proves the pattern against a real statement

## Fixtures Needed
No. Purpose strings inline, taken from real statement lines, as in 047.

### Refinement Tokens (estimate)
- Input: ~11k tokens
- Output: ~2k tokens

### Implementation Tokens (measured)
- Source: `/usage`, shared session — the baseline re-run and the 057/061/062 index commit ran in the same session before this
  ticket, so the figures are an upper bound for 050 alone. The bulk is this ticket: the dump run, the pattern and the docs
- Opus: 142 input, 44.9k output, 7.0m cache read, 133.7k cache write — $5.44
- Haiku 4.5: 4.4k input, 3.7k output — $0.12
- Session total $5.56, 11m53s API time. Cache read dominates by three orders of magnitude, which is the ticket's own lesson:
  the two evidence round-trips were cheap, re-reading the accumulated context on every turn was not
