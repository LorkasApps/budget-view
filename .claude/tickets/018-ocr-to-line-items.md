# OCR text → line-items

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | 017 |
| **Status** | Ready |

## Description
Convert an `OcrResult` (ticket 017) into a list of editable `LineItemCandidate`s and present them to the user in a preview screen (part of the scan flow from ticket 016). Parser uses simple heuristics (regex + row grouping by y-position). Rows the parser cannot decompose cleanly are surfaced as **unparsed** candidates showing the raw OCR text — the user completes them by hand before save. Rows detected as headers / totals / VAT lines are skipped.

Sign of amounts: line-items inherit the parent transaction's sign (rule from ticket 015) — the parser produces unsigned magnitudes, the flow applies the sign on convert.

The `ReceiptLineItemParser` interface and `LineItemCandidate` type already exist at `lib/features/drilldown/scan/domain/receipt_line_item_parser.dart`, with a `NoReceiptLineItemParser` stub. This ticket replaces the implementation only. Wire through `receiptLineItemParserProvider` in `photo_scan_providers.dart`. The review step integrates with `PhotoScanFlowController.confirm(edited:)`, which is the seam for passing back the user's edits. Restposten reconcile is already wired in 016's confirm path; this ticket inherits it.

## Types

```dart
enum LineItemParseState { ok, ambiguous, unparsed }

class LineItemCandidate {
  String description;                 // may be empty when parseState == unparsed
  int? amountCentsUnsigned;           // null when unparsed
  double? quantity;                   // optional
  int? unitPriceCentsUnsigned;        // optional
  String rawOcrText;                  // always set, source line(s) from OCR
  LineItemParseState parseState;
  bool includeInSave;                 // default: (parseState != unparsed)
}
```

## Parser

```dart
abstract class ReceiptLineItemParser {
  /// Convert an OCR result into candidate line-items.
  /// Empty output is valid (nothing on receipt looked like an item).
  List<LineItemCandidate> parse(OcrResult ocr);
}
```

`HeuristicReceiptLineItemParser` (concrete):
1. Group `OcrLine`s into rows by y-coordinate proximity (bounding-box overlap tolerance ~ half line height).
2. Skip rows whose text starts with (case-insensitive, normalized) any of: `summe`, `zwischensumme`, `total`, `mwst`, `ust`, `netto`, `brutto`, `gegeben`, `zurück`, `saldo`, `datum`, `uhrzeit`, `bon`, `filiale`, `kunden`, `karte`, `kasse`, `beleg`.
3. Find the rightmost currency-amount token per row (regex handles `1,23`, `1.23`, `1,23 €`, `€ 1,23`, thousands separators).
4. Text left of the amount → `description`.
5. Optional quantity pattern at start of description: `2x`, `2 x`, `1,5 kg`, `0.5 kg`, `3 Stk`. If matched, split into `quantity` + shortened description. If both `quantity` and `amountCents` present and division looks clean → set `unitPriceCentsUnsigned = round(amountCents / quantity)`.
6. If no amount found → `parseState = unparsed`, `rawOcrText = combined row text`, other fields blank.
7. If amount found but description empty (edge case) → `parseState = ambiguous`.

## Preview UI (extends scan flow from ticket 016)
- List of `LineItemCandidate`s in order.
- Per row:
  - `ok` state: description + amount + optional qty/unit-price + include-toggle + edit + delete.
  - `ambiguous` state: highlighted, needs user check.
  - `unparsed` state: shows `rawOcrText` in monospace with edit button; **cannot be saved** until description + amount set → toggle disabled.
- "Add manual row" action creates an empty candidate.
- "Categorize all" batch action opens category picker; per-row category picker also available (integrates 011 + 012 inheritance option).
- Footer shows live sum of included candidates + parent transaction total (sum validation warning belongs to 019, not this ticket — this ticket just renders the numbers).
- Confirm → for each `includeInSave = true` and valid candidate: build `LineItem` with parent transaction's sign applied, persist via `LineItemRepository.save`.

## Acceptance Criteria
- [ ] `LineItemCandidate` DTO defined in `lib/features/drilldown/scan/line_item_candidate.dart`
- [ ] `ReceiptLineItemParser` abstract interface + `HeuristicReceiptLineItemParser` concrete impl in `lib/features/drilldown/scan/receipt_line_item_parser.dart`
- [ ] `receiptLineItemParserProvider` (Riverpod) exposes parser, overridable in tests
- [ ] Currency regex handles `1,23`, `1.23`, `1234,56`, `1.234,56`, with/without `€`, with/without leading space
- [ ] Quantity regex handles `2x`, `2 x`, `1,5 kg`, `0.5 kg`, `3 Stk`, case-insensitive
- [ ] Header/total skip list applied case-insensitively after normalization (lower, trim)
- [ ] Preview screen (`ScanReviewScreen`) integrated into the scan flow after OCR (016) succeeds
- [ ] Confirm action applies parent transaction's sign, then calls `LineItemRepository.save` for each included candidate
- [ ] Confirm action calls `restpostenReconcilerProvider.reconcile(transactionUuid)` **once, after the last candidate is saved** (shipped in ticket 019). Reconciling per candidate would rewrite the managed row on every single row; skipping it leaves the booking's positions not adding up. This AC replaces the `scan_confirm_reconcile_test.dart` that 019 could not write, because the scan flow did not exist yet
- [ ] Unparsed candidates block save until description + amount set (include-toggle disabled)
- [ ] Categorization on preview writes to candidate; on save it becomes the `LineItem.categoryUuid` (null → later resolved via ticket 012)
- [ ] Post-confirm flow signals ticket 016 to write the `ImportedSource` row with correct `lineItemsProduced` count

## Test Strategy
- Parser tests use crafted `OcrResult` fixtures built inline — no image round-trip needed. Each test asserts candidate list, parseState, and field extraction.
- UI tests use a mocked parser to isolate preview behavior from heuristic tuning.

## Affected Tests
- `test/features/drilldown/scan/heuristic_line_item_parser_test.dart` — currency variants, quantity variants, skip list, unparsed fallback
- `test/features/drilldown/scan/scan_review_screen_test.dart` — include-toggle disabled for unparsed, batch categorize, add manual row
- `test/features/drilldown/scan/scan_review_persist_test.dart` — confirm persists with correct sign + counts

## Fixtures Needed
No — inline OCR result builders.

## Refinement Tokens (estimate)
- Input: ~12k tokens
- Output: ~4k tokens

## Token Usage
_Filled after Done._
