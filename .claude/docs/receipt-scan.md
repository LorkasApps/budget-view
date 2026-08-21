# Receipt photo capture (Drilldown domain)

Ephemeral one-shot capture workflow: camera or gallery source picker → optional
doc-hash warning (ticket 009) → OCR (ticket 017) / line-item parsing (ticket 018)
seams → user confirm → line-items persisted + ImportedSource row + bytes discarded.
`lib/features/drilldown/scan/`.

## Flow

```
[Scan source: Camera | Gallery]
        ↓
[Get bytes (Uint8List)]
        ↓
[Compute SHA-256 → check ImportedSource]
        ↓
    found? ── yes ──> [Warning modal: prev. import date + count]
        ↓                       ↓ user cancel: bytes dropped, exit
      no or proceed
        ↓
[OCR: hand bytes to OcrService (ticket 017)]
        ↓
[Parse: hand OcrResult to ReceiptLineItemParser (ticket 018)]
        ↓
[Review screen: user edits → returns edited list or null (ticket 018)]
        ↓         ↓ user discard: bytes dropped, exit
      proceed
        ↓
[Persist line-items → write ImportedSource → drop bytes]
```

## Interfaces and stubs

| Contract | Stub |
|----------|------|
| `OcrService.recognize(Uint8List) → Future<OcrResult>` — `OcrResult(fullText, blocks)`, `OcrBlock(text, boundingBox, lines)`, `OcrLine(text, boundingBox, confidence?)`; throws `OcrEngineException` | `MlKitOcrService` (ticket 017) via `google_mlkit_text_recognition` 0.16.0 |
| `ReceiptLineItemParser.parse(OcrResult) → ReceiptParseResult(candidates, printedTotalCents)` — `ReceiptParseResult(List<LineItemCandidate>, int?)`, `LineItemCandidate(description, amountCents?, quantity?, unitPriceCents?, rawOcrText, parseState, includeInSave, categoryUuid?)`, unsigned magnitudes | `HeuristicReceiptLineItemParser` — groups lines by vertical overlap across block boundaries, skips rows by prefix, rightmost price, reads printed total from totals row, drops rows without money tokens, quantity prefix parsing |
| `CapturedReceiptImage` — `bytes` + `filename` (empty for camera) | — |
| `ScanSource` enum: `camera` \| `gallery` | — |
| `ReceiptImageSource.pick(ScanSource) → Future<CapturedReceiptImage?>` | `ImagePickerReceiptImageSource` via `image_picker` 1.2.3 |
| `ReceiptImagePreprocessor.prepare(Uint8List) → Future<Uint8List>` | `JpegReceiptImagePreprocessor` — estimate tilt via projection profile, deskew, downscale to 2000 px max edge, re-encode JPEG @ 85% quality, returns original bytes if no changes, runs on helper isolate |

All in `lib/features/drilldown/scan/domain/` or `data/`.

## State machine

`ReceiptScanFlowController` (`AutoDisposeNotifier`) + `ReceiptScanFlowState`:

| Phase | Meaning |
|-------|---------|
| `idle` | Waiting for `startScan()` |
| `capturing` | Picking image from source |
| `hashing` | Computing SHA-256 of raw bytes |
| `duplicateWarning` | Doc-hash matched prior import; user decides `proceedAfterWarning()` or `cancel()` |
| `recognizing` | Running OCR on preprocessed bytes |
| `parsing` | Line-item parser executing |
| `awaitingConfirm` | Candidates ready; `confirm()` or `cancel()` |
| `persisting` | Saving line-items + ImportedSource row |
| `done` | Pass complete; ready for "Scan another" or exit |
| `cancelled` | User exited; no trace left |
| `failed` | Error on any step; `errorMessage` set |

State fields:

| Field | Type | Notes |
|-------|------|-------|
| `phase` | `ReceiptScanPhase` | Current step |
| `documentMatches` | `List<ImportedSource>` | Hits from doc-hash check, newest first (ticket 009) |
| `candidates` | `List<LineItemCandidate>` | Parsed positions (empty until `parsing` completes) |
| `filename` | `String` | Display name; empty for camera captures |
| `holdsImage` | `bool` | Mirrors the private `_bytes` reference; observable from UI + tests |
| `lineItemsPersisted` | `int` | Count of successfully saved items |
| `scansCompleted` | `int` | "Scan another" counter; the one field `startScan()` carries over between passes |
| `errorMessage` | `String?` | Error text when `phase == failed` |

Methods:

- `startScan({transaction, source})` — begins a pass; clears prior bytes/candidates/matches
- `proceedAfterWarning()` — user chose "Fortfahren" after doc-hash hit; proceeds to OCR
- `confirm({edited})` — persist candidates (or edited list from 018's review), write
  ImportedSource row, drop bytes; moves to `done`
- `cancel()` — exit cleanly without persisting anything

UI entry point: button in `LineItemsSection` (edit mode of `TransactionFormScreen`),
next to `+ Position`.

Modal chain: `showScanSourceSheet()` → `startReceiptScan(context, ref, transaction)`
holds a `listenManual` subscription for the flow's duration.

## Providers

| Provider | Purpose |
|----------|---------|
| `receiptImageSourceProvider` | `ImagePickerReceiptImageSource` instance |
| `receiptImagePreprocessorProvider` | `JpegReceiptImagePreprocessor` instance |
| `ocrServiceProvider` | `MlKitOcrService`; the native recognizer is long-lived and closed via `ref.onDispose` |
| `receiptLineItemParserProvider` | `HeuristicReceiptLineItemParser` instance |
| `receiptScanFlowProvider` | `AutoDisposeNotifier<ReceiptScanFlowState>` — **autoDispose on purpose** |

All wired in `domain/receipt_scan_providers.dart`.

## Parser — `HeuristicReceiptLineItemParser`

**Row grouping.** Lines are extracted from all blocks, sorted by vertical position,
then grouped into rows: two lines belong to the same row if their vertical centers
are within `(line height + row's max height) / 4` of each other. This merges a
description column and a price column that ML Kit often splits across blocks while
keeping unrelated text rows separate. Rows are sorted left-to-right and joined with
spaces.

**Skip list.** Rows whose normalized (lowercase, leading whitespace trimmed) start
matches any prefix in the skip set are discarded: `summe`, `zwischensumme`,
`total`, `mwst`, `ust`, `netto`, `brutto`, `gegeben`, `zurück`, `rückgeld`,
`saldo`, `datum`, `uhrzeit`, `bon`, `filiale`, `kunden`, `karte`, `kasse`,
`beleg`, `ec-cash`, `eur`, `gesamt`, `bargeld`, `girocard`, `ec-karte` — covering
totals, taxes, payment lines, and metadata.

**Printed total detection.** A row matching `summe`, `gesamt`, or `total` prefix,
with a readable money token, records that token as the receipt's printed total
(rightmost match wins if multiple). `zwischensumme` is deliberately excluded.
Rows without a money token are dropped entirely instead of becoming candidates.

**Money tokens.** The parser searches for price patterns: one to three digits per
group, groups separated by `,`, `.`, or space (e.g., `1,23`, `1.23`, `1.234,56`,
`1 234,56`), always ending in `,DD` (two decimal places). Optional `€` or `EUR` on
either side. The rightmost match in a row is the price.

**Quantity and unit price.** If a row starts with a count pattern (`2x`, `3 Stk`,
`3 Stk.`) or measure pattern (`1,5 kg`, `0.5 l`), it is parsed: count units (`x`,
`stk`, `stk.`, `stück`) are fully consumed from the description; measure units
(`kg`, `g`, `l`, `ml`) are left in the description because `LineItem` has no unit
field. `unitPriceCents` is derived only when the division `amountCents / quantity`
lands within a cent; otherwise it stays null — a mismatch is flagged by the UI's
warning instead of being invented.

**Parse states.** A row can land in `ok` (description and amount both read cleanly)
or `ambiguous` (amount but no description). `includeInSave` defaults to true for
`ok` rows, false for `ambiguous`. Rows without a money token are dropped.

## Review screen

`pushScanReview(context, transaction:, candidates:)` presents the parser's output
for editing and returns the reviewed list, or null if the user discards.

**Row states and rendering.**
- `ok`: plain `ListTile` — description, category chip once set, amount, quantity line
- `ambiguous`: same layout on a `tertiaryContainer` background, subtitle "Beschreibung fehlt"

The include-checkbox is **disabled for non-savable rows** — those lacking a
non-empty trimmed description or a positive amount. Disabled rows are skipped at
`confirm()`.

**Printed total banner.** Review screen shows a banner when the kept positions do
not sum to the printed total, naming both figures. Banner disappears when user
edits the selection (difference now intended).

**Row actions:** tap opens `showCandidateSheet`, a trailing icon deletes the row,
"Zeile hinzufügen" appends an empty one. Deliberately no swipe-to-delete: the rows
are not persisted yet, so the confirmation dance of `LineItemsSection` would be
theatre. An app-bar action categorizes every included, savable row at once.

**Footer.** Shows the included sum (rows with `includeInSave && isSavable`) against
the transaction's booking total.

**Return contract.** When the user taps the confirm button the return value is
`List<LineItemCandidate>?` — the edited list or null to discard. The flow passes
this into `confirm(edited:)`, which filters to `includeInSave && isSavable` rows.

## Non-obvious details

**Photo bytes never reach a repository.**
Bytes live in the controller's private `_bytes` field. Every exit path (`confirm`,
`cancel`, `_fail`, `_dropImage` on dispose) clears the reference. `state.holdsImage`
mirrors that fact so the rule is observable from tests and UI without exposing the
field.

**Doc-hash computed over raw capture.**
Hash is computed immediately after `pick()` returns, before preprocessing (deskew,
downscale). Otherwise a version bump in the `image` library or a deskew improvement
would shift the hash of the same document, breaking the re-scan warning. Preprocessed
bytes are handed to OCR only.

**`receiptScanFlowProvider` is `autoDispose`.**
The flow is temporary and so is the photo. Without `autoDispose` the controller
would persist after exiting the modal. The cost: `startReceiptScan` holds a
`ref.listenManual(receiptScanFlowProvider)` subscription for the flow's duration (see
`presentation/receipt_scan_flow.dart`). Without this listener the controller tears
down between awaits (e.g., between `startScan` returning and the doc-hash warning),
leaving `_bytes == null` and breaking the warning path.

**No separate detail screen, no grid, no scan counter in the transaction view.**
"Scan Kassenbon" is a single button next to `+ Position` inside `LineItemsSection`.
There is no photo grid, no "3 scans attached" badge. The modal flow is the only
entry point and exit is either `done` or `cancelled`; if the user starts fresh, they
pick a new source. This keeps the transaction form focused on the result (line-items)
not the process.

**No Android permissions.**
`image_picker` 1.2.3 uses the Photo Picker on API 33+ (no manifest entry), and
`ACTION_IMAGE_CAPTURE` for camera (no `CAMERA` permission). Declaring `CAMERA`
would trigger a runtime permission prompt; our code avoids it.

**Two temp files exist, neither is persistence.**
`image_picker` writes camera captures to a plugin-owned temp file whose path our code
never learns. And OCR needs one of its own: ML Kit refuses encoded images —
`InputImage.fromBytes` wants raw NV21 plus a rotation on Android — so
`MlKitOcrService` writes the downscaled bytes into the cache dir, recognizes from
that path, and deletes the file in a `finally`, including when the recognizer
throws. The alternative was owning YUV conversion *and* EXIF rotation in Dart, where
a mistake reads as garbage text rather than crashing. Nothing survives the flow;
"the photo is not kept" holds, "our code touches no file" does not.

**OCR error handling splits engine failure from an unreadable receipt.**
Every ML Kit failure is wrapped in `OcrEngineException` (German `message`), which the
controller's `failed` phase surfaces — `_fail` unwraps it like `LineItemInvalid`. An
empty result is *not* an error: it flows to `awaitingConfirm` with zero candidates,
where the confirm dialog already offers Abbrechen or "nur vermerken". A dedicated
retry loop is left to ticket 018, which builds the review surface anyway.

**German umlauts are not covered by `make check`.**
ML Kit has no binding in the test VM, so only our own seams are unit-tested: the
mapping, the error wrapping and the temp-file lifecycle (behind an injectable
`MlKitTextReader` port and an injectable cache directory). That Latin-script
recognition returns `Käse` / `Öl` / `Süß` / `Brühe` correctly is a device check —
same reasoning as the "no fixture PDFs" decision: a synthetically rendered image
would exercise a path no real receipt takes.

**Unsigned candidates, signed on persist.**
`LineItemCandidate` carries unsigned magnitudes: a receipt has no signs, so the
parser cannot know whether an item is expense or income. The transaction's sign is
applied in `confirm(edited:)` (`sign * amountCents`). This keeps the parser
receipt-focused and the validation rule simple. `LineItemValidation.amount` rejects
negatives, and ticket 015 owns the sign domain.

**Non-savable rows skipped at confirm, not rejected.**
If a row is `!isSavable` (empty description or non-positive amount), it is filtered
out during `confirm()` rather than being passed to the repository and rejected
there. This keeps the user's edits — an incomplete row survives to be finished later
— but prevents partial persistence in case `save()` rejects it mid-loop.

**Rejected candidate mid-`confirm()` leaves partial state.**
If `LineItemRepository.save()` rejects a candidate, earlier candidates stay persisted
and no `ImportedSource` row is written — and since the reconcile call sits behind the
loop, the managed Restposten row stays stale until the next write path on that
booking reconciles. No cross-repository transaction exists to roll this back. Only
savable rows are passed, so this case is now much harder to reach — it would require
a concurrent modification of the booking's sign after filtering.

**Restposten reconcile happens after all candidates saved.**
When `confirm()` persists one or more items, it calls
`restpostenReconcilerProvider.reconcile(transaction.uuid)` once (not per item). The
rule is identical to every other write path: positions moved, so the managed
remainder row must follow. This wiring already exists in ticket 016; ticket 018
inherits it.

**One `ImportedSource` row per confirmed pass.**
On `confirm()`, exactly one row is written:
- `kind = photo`
- `contentHashSha256 = raw-capture hash`
- `filename = user-visible name` (empty for camera)
- `importedAt = now`
- `transactionsProduced = 0` (017/018 handle line-items only, not splits)
- `lineItemsProduced = length(items)` (count of actually saved candidates)
- `note = 'Erneuter Scan trotz Warnung'` only when `documentSeenBefore` is true

**Zero items is a valid scan.**
A pass can propose zero line-items — the OCR found nothing item-like, or the user
discarded every row. `confirm()` writes the `ImportedSource` row anyway, so a
re-scan of the same photo warns.

## Testing

| File | Path | Scope |
|------|------|-------|
| `receipt_scan_flow_controller_test.dart` | `test/features/drilldown/scan/domain/` | State machine: happy path, cancel at each phase, error handling, bytes cleared on all exits |
| `receipt_scan_dochash_test.dart` | `test/features/drilldown/scan/domain/` | Doc-hash miss vs hit, user proceed, user cancel, warning modal, no ImportedSource on cancel |
| `receipt_scan_imported_source_test.dart` | `test/features/drilldown/scan/domain/` | ImportedSource row creation, correct field mapping, counts, no row on cancel, note only when warned |
| `receipt_scan_multi_test.dart` | `test/features/drilldown/scan/domain/` | "Scan another" within a flow: two passes produce two rows, each with correct counts |
| `receipt_scan_confirm_test.dart` | `test/features/drilldown/scan/domain/` | Confirm logic: sign application, filtering to savable rows, reconcile call, count in ImportedSource |
| `scan_test_support.dart` | `test/features/drilldown/scan/domain/` | Shared fakes: `FakeReceiptImageSource`, `FakeOcrService`, `FakeReceiptLineItemParser`, synthetic receipt bytes, test container builder |
| `receipt_skew_test.dart` | `test/features/drilldown/scan/data/` | Tilt sign for positive and negative tilt, straightening end-to-end, same instance when already straight, blank image |
| `mlkit_ocr_service_test.dart` | `test/features/drilldown/scan/data/` | OCR mapping (blocks, lines, boxes, confidence, `fullText`), bytes reach the temp file, empty result travels on, engine failure wrapped, temp file deleted on success and on throw |
| `heuristic_receipt_line_item_parser_test.dart` | `test/features/drilldown/scan/data/` | Row grouping across block boundaries, skip list (including new `gesamt`, `bargeld`, etc.), money tokens, printed total detection, `zwischensumme` not a total, quantity/unit parsing, rows without money dropped, parse states, candidates |
| `scan_review_screen_test.dart` | `test/features/drilldown/scan/presentation/` | UI: row states rendering, include-checkbox disabled rule, edit/add/delete/categorize, footer, return contract |

Not covered automatically: real ML Kit recognition (native plugin, device check).
