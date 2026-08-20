# V2 verification checklist: receipt scan and PDF receipts

| Field | Value |
|-------|-------|
| **Type** | TechDebt |
| **Epic** | None |
| **Domain** | Drilldown |
| **Blocked By** | 034, 035, 033 |
| **Severity** | Medium |
| **Effort** | L |
| **Status** | Draft |

## Description
Split out of ticket 028. The receipt area failed hard enough during the milestone-1 pass that walking the rest of its
checks would have measured a broken pipeline: prices pair with the wrong items on the slightest skew and the totals and
payment block arrive as positions (035), and the release build cannot recognise anything at all (034). Every remaining
check would have inherited those defects instead of testing its own subject.

So the receipt checks live here and run **after** their fixes land. The ticket also carries the human checks for PDF
receipts (033), which cannot be automated for the same structural reason: no test VM binding for the native halves, and
no test can judge whether a parsed invoice actually matches the paper.

Same rules as 028: this ticket produces findings, not code. Every deviation becomes its own Bug ticket referencing this
one, observations are noted inline behind the check, and `Done` means the pass happened — not that the app is clean.

## Risk if ignored
The scan pipeline is the only place in the app where data is *derived* rather than entered or imported, so it is the only
place that can be confidently wrong. Ticket 022 (price trends) reads exactly this data, and 023 will build on it.

## Verification Strategy
Physical Android device. Run each area **once on a release APK and once on debug** — 034 exists because those two
disagreed, and nothing in the automated suites can tell them apart. Have at least three receipts from different shops,
and at least two PDF invoices from different senders.

## Acceptance Criteria

### Receipt scan, re-run after 034 and 035 (016, 017, 018)
- [ ] Release APK recognises text at all — the exact failure of 034, re-checked on a shipped artifact rather than on
      `make run`
- [ ] OCR umlauts: a real receipt round-trips `Käse`, `Öl`, `Süß`, `Brühe` in the review screen
- [ ] Rotation: a portrait capture is recognized as well as a landscape one — ML Kit reading EXIF through
      `InputImage.fromFilePath` is the assumption behind the temp-file detour
- [ ] Heuristic accuracy on ≥ 3 receipts from different shops: note how many rows land `ok` / `ambiguous` / `unparsed`,
      and whether two receipt rows were ever merged into one candidate
- [ ] Prices land on the right rows, including on a deliberately skewed photo (035's first half)
- [ ] No address, totals, `Bargeld`, `Rückgeld` or EC terminal row becomes a position (035's second half)
- [ ] Review screen: toggles, row edit, `Zeile hinzufügen`, `alle kategorisieren` behave on a real list
- [ ] Confirm persists with the right sign and the Restposten closes the gap
- [ ] Re-scanning the same photo triggers the doc-hash warning, and proceeding notes `Erneuter Scan trotz Warnung`
- [ ] `Weiteren Bon scannen` runs a second pass on the same booking
- [ ] Cache directory holds no `scan_*.jpg` leftovers after several passes (the `finally` delete fires on device)

### PDF receipts (033)
- [ ] The source picker offers the PDF path, and `file_selector` returns a real invoice
- [ ] A digital invoice parses **without** OCR — recognition must not be involved at all for a PDF carrying a text layer
- [ ] Positions match the paper: descriptions, prices, and quantity / unit price where the invoice prints them
- [ ] Umlauts survive text extraction (a different code path from OCR: Syncfusion, not ML Kit)
- [ ] An invoice from a **second** sender is either parsed or refused with a readable message — never silently
      half-parsed, same bar as the statement import
- [ ] A scanned PDF **without** a text layer behaves as 033 decided (refuse with a message, or fall back) — and whatever
      it does, it says so
- [ ] Multi-page invoice: whatever 033 decided about pages holds, and nothing is silently dropped
- [ ] The invoice attaches to the intended booking, and the Restposten closes the remaining gap
- [ ] Confirm writes one `ImportedSource` row whose kind and label read correctly in the import history — the enum
      question of 033 becomes visible exactly here
- [ ] Re-picking the same PDF triggers the doc-hash warning with wording that fits a receipt, not a bank statement
- [ ] Total-as-checksum, if 035 implemented it: a manipulated or misparsed invoice is flagged rather than accepted

## Affected Tests
None — this ticket adds no automated test. Findings may add them through their own Bug tickets. Note that PDF parsing,
unlike OCR, *is* unit-testable, so a finding here should usually become a test rather than another manual check.

## Fixtures Needed
No — real receipts and real invoices, both kept out of git.

## Token Usage
_Filled after Done._
