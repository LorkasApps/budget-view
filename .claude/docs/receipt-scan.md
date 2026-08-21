# Receipt capture (Drilldown domain)

Ephemeral one-shot capture workflow: camera / gallery / PDF source picker → optional
doc-hash warning (ticket 009) → parse (OCR via ticket 017, or PDF via ticket 033) / line-item
parsing (ticket 018) seams → user confirm → line-items persisted + ImportedSource row + bytes
discarded. `lib/features/drilldown/scan/`.

## Flow

```
[Scan source: Camera | Gallery | PDF]
        ↓
[Get bytes (Uint8List)]
        ↓
[Compute SHA-256 → check ImportedSource]
        ↓
    found? ── yes ──> [Warning modal: prev. import date + count]
        ↓                       ↓ user cancel: bytes dropped, exit
      no or proceed
        ↓
    ┌─────────────────────────────────┬──────────────────────────────┐
    ↓ Camera/Gallery                   ↓ PDF
[OCR: hand bytes to OcrService]   [Read: hand bytes to ReceiptPdfReader]
(ticket 017)                      (ticket 033)
    ↓                                 ↓ null? ──> fail: "no text layer,
[Parse: hand OcrResult to]        photograph instead"
ReceiptLineItemParser (018)           ↓
    │                           [Parse: hand ReceiptWord list to
    └─────────────────┬──────────────────────────────┘ parseReceiptPdf]
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
| `OcrService.recognize(Uint8List) → Future<OcrResult>` — `OcrResult(fullText, blocks)`, `OcrBlock(text, boundingBox, lines)`, `OcrLine(text, boundingBox, confidence?)`; throws `OcrEngineException` | `MlKitOcrService` (ticket 017) via `google_mlkit_text_recognition` 0.17.1 |
| `ReceiptLineItemParser.parse(OcrResult) → ReceiptParseResult` | `HeuristicReceiptLineItemParser` — groups lines by vertical overlap, skips rows by prefix, rightmost price, printed total from totals row, drops rows without money tokens, quantity parsing |
| `ReceiptPdfReader.read(Uint8List) → ReceiptParseResult?` — null = no text layer (document is scan; route to OCR) | `SyncfusionReceiptPdfReader` (ticket 033) — extracts words via `syncfusion_flutter_pdf`, delegates to `parseReceiptPdf` |
| `ReceiptParseResult(List<LineItemCandidate>, int? printedTotalCents, int creditCents = 0)` with derived `expectedPositionSumCents` = total + credits — `LineItemCandidate(description, amountCents?, quantity?, unitPriceCents?, rawOcrText, parseState, includeInSave, categoryUuid?)`, unsigned magnitudes | — |
| `PickedReceiptDocument` — `bytes` + `filename` | — |
| `ReceiptSource` enum: `camera` \| `gallery` \| `pdf` | — |
| `ReceiptImageSource.pick(ScanSource) → Future<CapturedReceiptImage?>` | `ImagePickerReceiptImageSource` via `image_picker` 1.2.3 |
| `ReceiptPdfSource.pick() → Future<PickedReceiptDocument?>` | `FileSelectorReceiptPdfSource` (ticket 033) via `file_selector` |
| `ReceiptImagePreprocessor.prepare(Uint8List) → Future<Uint8List>` | `JpegReceiptImagePreprocessor` — estimate tilt via projection profile, deskew, downscale to 2000 px max edge, re-encode JPEG @ 85% quality, returns original if unchanged, runs on helper isolate |

All in `lib/features/drilldown/scan/domain/` or `data/`. `ReceiptSource.asScanSource` maps camera/gallery to `ScanSource`, yields null for pdf (diverges after picking).

## State machine

`ReceiptScanFlowController` (`AutoDisposeNotifier`) + `ReceiptScanFlowState`:

| Phase | Meaning |
|-------|---------|
| `idle` | Waiting for `startScan()` |
| `capturing` | Picking image or PDF from source |
| `hashing` | Computing SHA-256 of raw bytes |
| `duplicateWarning` | Doc-hash matched prior import; user decides `proceedAfterWarning()` or `cancel()` |
| `recognizing` | Running OCR on preprocessed image bytes. The PDF path skips this phase — reading a text layer is synchronous and goes straight to `parsing` |
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
| `kind` | `ImportedSourceKind` | `photo` or `receiptPdf`; set by source, written to ImportedSource row |
| `documentMatches` | `List<ImportedSource>` | Hits from doc-hash check, newest first (ticket 009) |
| `candidates` | `List<LineItemCandidate>` | Parsed positions (empty until `parsing` completes) |
| `filename` | `String` | Display name; empty for camera captures |
| `holdsImage` | `bool` | Mirrors the private `_bytes` reference; observable from UI + tests |
| `lineItemsPersisted` | `int` | Count of successfully saved items |
| `scansCompleted` | `int` | "Scan another" counter; the one field `startScan()` carries over between passes |
| `errorMessage` | `String?` | Error text when `phase == failed` |

Methods:

- `startScan({transaction, source})` — begins a pass; clears prior bytes/candidates/matches; sets `kind` from source
- `proceedAfterWarning()` — user chose "Fortfahren" after doc-hash hit; proceeds to read (OCR or PDF per `kind`)
- `confirm({edited})` — persist candidates (or edited list from 018's review), write
  ImportedSource row with `kind`, drop bytes; moves to `done`
- `cancel()` — exit cleanly without persisting anything

UI entry point: button in `LineItemsSection` (edit mode of `TransactionFormScreen`),
next to `+ Position`.

Modal chain: `showScanSourceSheet()` → `startReceiptScan(context, ref, transaction)`
holds a `listenManual` subscription for the flow's duration.

## Providers

| Provider | Purpose |
|----------|---------|
| `receiptImageSourceProvider` | `ImagePickerReceiptImageSource` instance |
| `receiptPdfSourceProvider` | `FileSelectorReceiptPdfSource` instance |
| `receiptImagePreprocessorProvider` | `JpegReceiptImagePreprocessor` instance |
| `ocrServiceProvider` | `MlKitOcrService`; the native recognizer is long-lived and closed via `ref.onDispose` |
| `receiptPdfReaderProvider` | `SyncfusionReceiptPdfReader` instance |
| `receiptLineItemParserProvider` | `HeuristicReceiptLineItemParser` instance |
| `receiptScanFlowProvider` | `AutoDisposeNotifier<ReceiptScanFlowState>` — **autoDispose on purpose** |

All wired in `domain/receipt_scan_providers.dart`.

## Parser — `HeuristicReceiptLineItemParser` (Photo OCR)

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

**Credits.** Rows starting with `eingereichtes`, `rückgabe`, `gutschrift`, or `erstattung`
are summed into `ReceiptParseResult.creditCents` instead of becoming line-item candidates.
The review screen compares `lineItemsSumCents + creditCents` against `printedTotalCents`.

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

## Parser — `parseReceiptPdf` (PDF Text Layer)

**Word extraction.** `ReceiptWord(page, left, top, width, height, text)` plus derived
`right`, `bottom`, `centerY`. Coordinates are top-left origin; larger `top` = further down
page. Words extracted via Syncfusion and passed to `parseReceiptPdf(List<ReceiptWord>)`.

**Item clustering.** Words are grouped vertically into item blocks: two words belong to the
same block if their baselines are within `1.6 × median-word-height` of each other. Each
block contributes one candidate.

**Price column detection.** Rightmost price-shaped fragment (money token or digit band) in
the right half of the page wins; no fixed fraction. Money patterns: 1–3 digits per group,
separated by `,` / `.` / space, ending in `,DD` (cents). Optional `€` or `EUR`.

**Amount reassembly.** A printed price splits across baselines: large integer, raised cents,
period. A band of fragments (words within one cluster's vertical span) is read left-to-right;
last two digits become cents. The **bottom-most** band of a block wins (strikes through
original, keeps real price).

**Row gluing.** Words whose gap is under 1/8 of the tolerance are joined (`Röstkaf` + `fee`
→ `Röstkaffee`).

**Printed total and credits.** Rows starting with total prefixes (`summe`, `gesamt`, `total`)
set `printedTotalCents`; rows starting with credit prefixes (`eingereichtes`, `rückgabe`,
`gutschrift`, `erstattung`) add to `creditCents`. Rows matching skip vocabulary are dropped
(same list as OCR: `zwischensumme`, `mwst`, etc.). Rows without an amount are dropped.

**Quantity and unit price.** A leftmost column number is the quantity (one fragment in its own
column at left edge). `unitPriceCents` derived only if `amountCents / quantity` lands within
a cent.

**Plausibility.** **No position may cost more than the printed total** — bounds page furniture
without sender vocabulary.

## Known sender layouts

Measured on real documents, kept here because the same receipt can arrive as a PDF **or** as a photo/screenshot, and the
two paths use different parsers. The PDF parser (`parseReceiptPdf`, `data/pdf_receipt_parser.dart`, ticket 033)
implements all of these; the OCR parser (`HeuristicReceiptLineItemParser`, above) implements the ones marked accordingly.

**Picnic** (delivery service; PDF is a browser print of the confirmation mail):

| Trait | Consequence | In OCR parser | In PDF parser |
|-------|-------------|---------------|--------------| 
| Columns: quantity far left (x≈149), description (x≈212), price right (x≈430) | A lone number in its own column is the quantity | no — OCR reads a leading `2x` instead | yes |
| A price is three words on three baselines: large integer, raised cents, period | Digits of a band are read left to right, last two are cents | no — an OCR row is one string | yes |
| Two prices per row: struck-through original **above**, real price **below** | The **bottom-most** band of a block wins | **no — OCR parser takes rightmost token, struck-through can win** | yes |
| `Eingereichtes Pfand` is a credit the printed total already accounts for | Subtracted in checksum, never a position | ticket **043** (OCR mismatch report) | yes |
| Page furniture (mail header, register number, URLs) reassembles into amounts | Nothing may cost more than the printed total | no | yes |
| `Pfand` total is a real position; `Tüten` / `Flaschen` breakdown is not | Skip breakdown, keep total | partly — `pfand` not in OCR skip list | yes |
| PDF text layers split words at ligatures (`Röstkaf` + `fee`, gap 0 vs 3+) | Glue below 1/8 of tolerance | not applicable | yes |

The gaps in the OCR column are ticket **043**.

## Review screen

`pushScanReview(context, transaction:, candidates:)` presents the parser's output
for editing and returns the reviewed list, or null if the user discards.

**Row states and rendering.**
- `ok`: plain `ListTile` — description, category chip once set, amount, quantity line
- `ambiguous`: same layout on a `tertiaryContainer` background, subtitle "Beschreibung fehlt"

The include-checkbox is **disabled for non-savable rows** — those lacking a
non-empty trimmed description or a positive amount. Disabled rows are skipped at
`confirm()`.

**Printed total banner.** Review screen shows a banner when the kept positions plus
credits do not sum to the printed total, naming both figures. Banner disappears when
user edits the selection (difference now intended).

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
- `kind = photo | receiptPdf` (set from `ReceiptSource`, written to state.kind)
- `contentHashSha256 = raw-capture hash`
- `filename = user-visible name` (empty for camera; PDF picker provides it)
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
| `receipt_scan_flow_controller_test.dart` | `test/features/drilldown/scan/domain/` | State machine: photo and PDF paths, cancel at each phase, error handling, bytes cleared on all exits |
| `receipt_scan_dochash_test.dart` | `test/features/drilldown/scan/domain/` | Doc-hash miss vs hit, user proceed/cancel, warning modal, no ImportedSource on cancel |
| `receipt_scan_imported_source_test.dart` | `test/features/drilldown/scan/domain/` | ImportedSource row creation, `kind` field set from source, correct field mapping, counts, note only when warned |
| `receipt_scan_multi_test.dart` | `test/features/drilldown/scan/domain/` | "Scan another" within a flow: two passes produce two rows with correct `kind` and counts |
| `receipt_scan_confirm_test.dart` | `test/features/drilldown/scan/domain/` | Confirm logic: sign application, filtering to savable rows, reconcile call, `kind` persisted to ImportedSource |
| `receipt_scan_pdf_test.dart` | `test/features/drilldown/scan/domain/` | PDF flow: pick, hashing, doc-hash path, successful read, null read (no text layer), error handling |
| `scan_test_support.dart` | `test/features/drilldown/scan/domain/` | Shared fakes: `FakeReceiptImageSource`, `FakeReceiptPdfSource`, `FakeOcrService`, `FakeReceiptLineItemParser`, `FakePdfReader`, synthetic bytes, test container |
| `receipt_skew_test.dart` | `test/features/drilldown/scan/data/` | Tilt sign (positive/negative), straightening, same instance when straight, blank image |
| `mlkit_ocr_service_test.dart` | `test/features/drilldown/scan/data/` | OCR mapping (blocks, lines, boxes, confidence), temp file lifecycle, empty result, engine failure wrapped, cleanup on throw |
| `heuristic_receipt_line_item_parser_test.dart` | `test/features/drilldown/scan/data/` | Row grouping across blocks, skip list, money tokens, printed total, `zwischensumme` excluded, credit rows, quantity/unit parsing, rows without money dropped |
| `pdf_receipt_parser_test.dart` | `test/features/drilldown/scan/data/` | Item clustering, price column detection, amount reassembly, bottom-most band wins, quantity parsing, word gluing, printed total, credits, plausibility bound, synthetic words |
| `receipt_pdf_dump_test.dart` (env-gated `RECEIPT_PDF`) | `test/tool/` | Real PDF parsing, decision reporting via test output |
| `scan_review_screen_test.dart` | `test/features/drilldown/scan/presentation/` | UI: row states, include-checkbox disabled rule, edit/add/delete/categorize, footer, return contract |

Not covered automatically: real ML Kit recognition (native plugin, device check), real PDF text extraction (Syncfusion).
