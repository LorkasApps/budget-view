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
[Confirm / Cancel]
        ↓
[Persist line-items → write ImportedSource → drop bytes]
```

## Interfaces and stubs

| Contract | Stub |
|----------|------|
| `OcrService.recognize(Uint8List) → Future<OcrResult>` — `OcrResult(fullText, blocks)`, `OcrBlock(text, boundingBox, lines)`, `OcrLine(text, boundingBox, confidence?)`; throws `OcrEngineException` | `MlKitOcrService` (ticket 017) via `google_mlkit_text_recognition` 0.16.0; `NoOcrService` remains as the test override and the recognizer-less fallback |
| `ReceiptLineItemParser.parse(OcrResult, transactionSign) → List<LineItemCandidate>` | `NoReceiptLineItemParser` — returns empty list |
| `CapturedReceiptImage` — `bytes` + `filename` (empty for camera) | — |
| `ScanSource` enum: `camera` \| `gallery` | — |
| `ReceiptImageSource.pick(ScanSource) → Future<CapturedReceiptImage?>` | `ImagePickerReceiptImageSource` via `image_picker` 1.2.3 |
| `ReceiptImagePreprocessor.prepare(Uint8List) → Future<Uint8List>` | `JpegReceiptImagePreprocessor` — downscale to 2000 px max edge, re-encode JPEG @ 85% quality, runs on helper isolate |

All in `lib/features/drilldown/scan/domain/` or `data/`.

## State machine

`PhotoScanFlowController` (`AutoDisposeNotifier`) + `PhotoScanFlowState`:

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
| `phase` | `PhotoScanPhase` | Current step |
| `documentMatches` | `List<ImportedSource>` | Hits from doc-hash check, newest first (ticket 009) |
| `candidates` | `List<LineItemCandidate>` | Parsed positions (empty until `parsing` completes) |
| `filename` | `String` | Display name; empty for camera captures |
| `holdsImage` | `bool` | Mirrors the private `_bytes` reference; observable from UI + tests |
| `lineItemsPersisted` | `int` | Count of successfully saved items |
| `scansCompleted` | `int` | "Scan another" counter; reset to 0 on `startScan()` for the first pass |
| `errorMessage` | `String?` | Error text when `phase == failed` |

Methods:

- `startScan({transaction, source})` — begins a pass; clears prior bytes/candidates/matches
- `proceedAfterWarning()` — user chose "Fortfahren" after doc-hash hit; proceeds to OCR
- `confirm({edited})` — persist candidates (or edited list from 018's review), write
  ImportedSource row, drop bytes; moves to `done`
- `cancel()` — exit cleanly without persisting anything

UI entry point: button in `LineItemsSection` (edit mode of `TransactionFormScreen`),
next to `+ Position`.

Modal chain: `showScanSourceSheet()` → `startPhotoScan(context, ref, transaction)`
holds a `listenManual` subscription for the flow's duration.

## Providers

| Provider | Purpose |
|----------|---------|
| `receiptImageSourceProvider` | `ImagePickerReceiptImageSource` instance |
| `receiptImagePreprocessorProvider` | `JpegReceiptImagePreprocessor` instance |
| `ocrServiceProvider` | `MlKitOcrService`; the native recognizer is long-lived and closed via `ref.onDispose` |
| `receiptLineItemParserProvider` | `NoReceiptLineItemParser` stub (ticket 018 replaces impl) |
| `photoScanFlowProvider` | `AutoDisposeNotifier<PhotoScanFlowState>` — **autoDispose on purpose** |

All wired in `domain/photo_scan_providers.dart`.

## Non-obvious details

**Photo bytes never reach a repository.**
Bytes live in the controller's private `_bytes` field. Every exit path (`confirm`,
`cancel`, `_fail`, `_dropImage` on dispose) clears the reference. `state.holdsImage`
mirrors that fact so the rule is observable from tests and UI without exposing the
field.

**Doc-hash computed over raw capture.**
Hash is computed immediately after `pick()` returns, before downscaling. Otherwise a
version bump in the `image` library would shift the hash of the same document,
breaking the re-scan warning. Downscaled bytes are handed to OCR only.

**`photoScanFlowProvider` is `autoDispose`.**
The flow is temporary and so is the photo. Without `autoDispose` the controller
would persist after exiting the modal. The cost: `startPhotoScan` holds a
`ref.listenManual(photoScanFlowProvider)` subscription for the flow's duration (see
`presentation/photo_scan_flow.dart`). Without this listener the controller tears
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

**Rejected candidate mid-`confirm()` leaves partial state.**
If `LineItemRepository.save()` rejects a candidate, earlier candidates stay persisted
and no `ImportedSource` row is written — and since the reconcile call sits behind the
loop, the managed Restposten row stays stale until the next write path on that
booking reconciles. No cross-repository transaction exists to roll this back. Ticket
018's review step validates all candidates before returning, which is what keeps the
case unreachable in practice.

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
A pass can propose zero line-items — an unreadable receipt, or the parser stub still
in place until 018. `confirm()` writes the `ImportedSource` row anyway, so a re-scan
of the same photo warns.

## Testing

| File | Path | Scope |
|------|------|-------|
| `photo_scan_flow_controller_test.dart` | `test/features/drilldown/scan/domain/` | State machine: happy path, cancel at each phase, error handling, bytes cleared on all exits |
| `photo_scan_dochash_test.dart` | `test/features/drilldown/scan/domain/` | Doc-hash miss vs hit, user proceed, user cancel, warning modal, no ImportedSource on cancel |
| `photo_scan_imported_source_test.dart` | `test/features/drilldown/scan/domain/` | ImportedSource row creation, correct field mapping, counts, no row on cancel, note only when warned |
| `photo_scan_multi_test.dart` | `test/features/drilldown/scan/domain/` | "Scan another" within a flow: two passes produce two rows, each with correct counts |
| `scan_test_support.dart` | `test/features/drilldown/scan/domain/` | Shared fakes: `FakeReceiptImageSource`, `FakeOcrService`, `FakeReceiptLineItemParser`, synthetic receipt bytes, test container builder |
| `mlkit_ocr_service_test.dart` | `test/features/drilldown/scan/data/` | OCR mapping (blocks, lines, boxes, confidence, `fullText`), bytes reach the temp file, empty result travels on, engine failure wrapped, temp file deleted on success and on throw |

Not covered automatically: real ML Kit recognition (native plugin, device check).
