# OCR text → line-items

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | 017 |
| **Status** | Done |

## Description
Convert an `OcrResult` (ticket 017) into a list of editable `LineItemCandidate`s and present them to the user in a preview screen (part of the scan flow from ticket 016). Parser uses simple heuristics (regex + row grouping by y-position). Rows the parser cannot decompose cleanly are surfaced as **unparsed** candidates showing the raw OCR text — the user completes them by hand before save. Rows detected as headers / totals / VAT lines are skipped.

Sign of amounts: line-items inherit the parent transaction's sign (rule from ticket 015) — the parser produces unsigned magnitudes, the flow applies the sign on convert.

The `ReceiptLineItemParser` interface and `LineItemCandidate` type already exist at `lib/features/drilldown/scan/domain/receipt_line_item_parser.dart` (016's `NoReceiptLineItemParser` stub was deleted here, since nothing referenced it once the heuristic landed). Wire through `receiptLineItemParserProvider` in `photo_scan_providers.dart`. The review step integrates with `PhotoScanFlowController.confirm(edited:)`, which is the seam for passing back the user's edits. Restposten reconcile is already wired in 016's confirm path; this ticket inherits it.

Device verification (umlauts from 017, plus this ticket's heuristic accuracy) moved to **028**, on request: app testing happens once the feature set is written, in one pass rather than per ticket.

## Re-verify after blocker 017 (2026-08-17)
Kept as one ticket on request, parser and review surface together. Seven points against what 016/017 shipped:

1. **`LineItemCandidate` switches from signed to unsigned, and `parse` loses `transactionSign`.** 016 shipped a signed amount and pushed the parent's sign into the parser. But a receipt has no signs, `LineItemValidation.amount` rejects negatives outright ("Betrag ohne Vorzeichen eingeben"), and 015 puts the sign on the parent. So the parser reads magnitudes and the flow applies the sign at persist time — one transformation point instead of two. 016's controller and the test fakes follow.
2. **Candidate stays immutable with `copyWith`.** The review surface edits rows, but a mutable DTO inside Riverpod state would mutate under the widget tree. The review screen owns a local list and swaps entries.
3. **Paths** follow 016's split: DTO plus contract in `scan/domain/`, `HeuristicReceiptLineItemParser` in `scan/data/`, review surface in `scan/presentation/` — not the flat `scan/` paths this ticket originally named.
4. **Two ACs are already satisfied by 016** and only need verification, not code: the single reconcile call after the last save, and the `ImportedSource` row carrying `lineItemsProduced`. What does change: both must count *included* candidates only, so the filter runs before either.
5. **The review surface is a pushed screen, not another dialog.** 016's `startPhotoScan` drives a modal chain; the screen returns `List<LineItemCandidate>?` into the existing `confirm(edited:)` seam, replacing 016's placeholder confirm dialog. The flow's `listenManual` subscription outlives the push, so the photo bytes survive the detour.
6. **Amount parsing reuses `parseEurosToCents`** after normalizing thousands separators — `"1.234,56"` breaks it as-is, since it swaps every comma for a dot. No second money parser.
7. **Device check for umlauts lands here**, inherited from 017: this screen is the first surface that shows recognized text.

## Types

```dart
enum LineItemParseState { ok, ambiguous, unparsed }

class LineItemCandidate {
  final String description;           // empty when parseState == unparsed
  final int? amountCents;             // unsigned magnitude, null when unparsed
  final double? quantity;             // optional
  final int? unitPriceCents;          // unsigned magnitude, optional
  final String rawOcrText;            // always set, source row text from OCR
  final LineItemParseState parseState;
  final bool includeInSave;           // default: parseState == ok
  final String? categoryUuid;         // null → inherits from the booking (012)

  bool get isSavable;                 // description + amount present
  LineItemCandidate copyWith({...});
}
```

## Parser

```dart
abstract interface class ReceiptLineItemParser {
  /// Empty output is valid — nothing on the receipt looked like an item.
  /// Amounts are unsigned; the scan flow applies the booking's sign.
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
- [x] `LineItemCandidate` + `LineItemParseState` in `lib/features/drilldown/scan/domain/receipt_line_item_parser.dart` (next to the contract, as 016 placed them), unsigned amounts, immutable with `copyWith`
- [x] `HeuristicReceiptLineItemParser` in `lib/features/drilldown/scan/data/heuristic_receipt_line_item_parser.dart`
- [x] `receiptLineItemParserProvider` yields the heuristic parser, still overridable in tests
- [x] Rows built by grouping `OcrLine`s across all blocks by vertical overlap (tolerance ≈ half line height), ordered top to bottom, then left to right within a row
- [x] Currency token handles `1,23`, `1.23`, `1234,56`, `1.234,56`, with and without `€`, with and without a space; the rightmost token in a row wins; parsing goes through `parseEurosToCents` after stripping thousands separators
- [x] Quantity prefix handles `2x`, `2 x`, `1,5 kg`, `0.5 kg`, `3 Stk`, case-insensitive; matched prefix is removed from the description
- [x] `unitPriceCents` derived only when quantity and amount are both present and the division lands within a cent — a mismatch stays a warning in the UI, never a silent value
- [x] Header/total skip list applied case-insensitively after normalization; a skipped row produces no candidate
- [x] No amount in a row → `parseState = unparsed`, `rawOcrText` kept, `includeInSave = false`; amount without description → `ambiguous`
- [x] `ScanReviewScreen` pushed from the scan flow after OCR, returns the edited candidate list into `PhotoScanFlowController.confirm(edited:)`; 016's placeholder confirm dialog is removed
- [x] Review rows: `ok` plain, `ambiguous` highlighted, `unparsed` shows `rawOcrText` in monospace; include-toggle disabled while a row is not savable
- [x] Row edit sheet mirrors `line_item_edit_sheet.dart` (description, magnitude, optional quantity + unit price, mismatch warning, category row) and reuses `LineItemValidation`
- [x] "Zeile hinzufügen" appends an empty candidate; per-row and "alle kategorisieren" both go through `pickCategory` (`allowNone: true`, inherit label like the position sheet)
- [x] Footer shows the live sum of included candidates against the booking total (rendering only — 019 owns the invariant)
- [x] Confirm persists only `includeInSave` candidates, applying the booking's sign, category included (null → inherits per 012)
- [x] Already shipped in 016, to be verified rather than rebuilt: one `reconcile` call after the last save, and one `ImportedSource` row whose `lineItemsProduced` counts the *included* candidates

## Test Strategy
- Parser tests use crafted `OcrResult` fixtures built inline — no image round-trip needed. Each test asserts candidate list, parseState, and field extraction.
- UI tests use a mocked parser to isolate preview behavior from heuristic tuning.

## Affected Tests
- `test/features/drilldown/scan/data/heuristic_receipt_line_item_parser_test.dart` — row grouping by y-overlap, currency variants, quantity variants, unit-price derivation, skip list, unparsed and ambiguous fallbacks
- `test/features/drilldown/scan/presentation/scan_review_screen_test.dart` — toggle disabled while a row is not savable, edit makes an unparsed row savable, add row, categorize all
- `test/features/drilldown/scan/domain/photo_scan_confirm_test.dart` — confirm persists only included candidates with the booking's sign and the chosen category, reconciles once, and counts the included rows in `ImportedSource`
- `test/features/drilldown/scan/domain/scan_test_support.dart` — fakes follow the unsigned, `transactionSign`-free contract

## Fixtures Needed
No — inline OCR result builders.

## Refinement Tokens (estimate)
- Input: ~12k tokens
- Output: ~4k tokens

### Implementation Tokens (estimate)
- Input: ~130k tokens
- Output: ~20k tokens
