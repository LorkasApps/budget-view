# Kassenbon photo capture (ephemeral)

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | 015, 009 |
| **Status** | Ready |

## Description
Capture receipt photos (camera or gallery) for a specific `Transaction`. **Photos are ephemeral** — bytes live only in memory during the scan flow, are passed to OCR (ticket 017) and line-item parsing (ticket 018), then discarded. No file storage, no `Receipt` entity.

Multiple photos per transaction supported: user scans them sequentially, each photo flows through capture → doc-hash-check → OCR → line-item extraction → add to the transaction's line-items. Doc-hash check (ticket 009) prevents re-scanning the same photo.

## Flow

```
[Transaction detail: "Scan Kassenbon" action]
        ↓
[Pick source: Camera | Gallery]
        ↓
[Get bytes (Uint8List, in-memory)]
        ↓
[Compute contentHash SHA-256 → check ImportedSource]
        ↓
      match? ── yes ──> [Warning modal → user proceed or cancel]
        ↓                                    ↓ cancel: bytes discarded, exit
      proceed
        ↓
[Hand bytes to OCR service (ticket 017)]
        ↓
[Hand OCR result to line-item parser (ticket 018)]
        ↓
[User reviews / edits line-item candidates]
        ↓
[Confirm → persist line-items via LineItemRepository]
        ↓
[Write ImportedSource row: kind=photo, hash, filename (if any), counts]
        ↓
[Discard bytes → exit flow]
        ↓
[Offer "Scan another" or "Done"]
```

## Acceptance Criteria
- [ ] `image_picker` dependency added
- [ ] `path_provider` dependency added (needed by `image_picker` under the hood; not for our storage)
- [ ] `image` (Dart image lib) dependency added — used only for optional in-memory resize before OCR (max 2000 px longer side, JPEG quality 85) to keep OCR fast
- [ ] Android `CAMERA` runtime permission requested on first camera use
- [ ] Android `READ_MEDIA_IMAGES` (API 33+) runtime permission requested for gallery pick
- [ ] Transaction detail screen: **no photo grid**; instead a "Scan Kassenbon" action button + a live count of "line-items from scans" (informational)
- [ ] "Scan Kassenbon" opens the capture flow above
- [ ] Camera / Gallery source picker bottom sheet
- [ ] `PhotoScanFlowController` (Riverpod StateNotifier) holds bytes in memory, orchestrates the flow, exposes state (idle, hashing, oc-r running, awaiting-confirm, persisting, done, cancelled)
- [ ] Controller **clears** bytes reference on any exit path (confirm, cancel, error)
- [ ] Doc-hash check integrates ticket 009's `duplicateCheckerProvider.findDocumentMatches(hash)` — if match, show modal with previous-import summary + Proceed/Cancel
- [ ] After user confirms line-items: one `ImportedSource` row created (`kind=photo`, hash, filename may be empty for camera captures, `lineItemsProduced=N`, `transactionsProduced=0`)
- [ ] "Scan another" restarts the flow within the same transaction detail (fresh capture, new hash, new pass)
- [ ] Cancel at any step: bytes discarded, no `ImportedSource` row, transaction unchanged
- [ ] No path is ever written to disk by this ticket

## Handoff Contracts
- **To ticket 017 (OCR):** `OcrService.recognize(Uint8List bytes) → Future<OcrResult>` — full contract owned by 017; this ticket only calls it
- **To ticket 018 (line-item parsing):** `ReceiptLineItemParser.parse(OcrResult, transactionSign) → List<LineItemCandidate>` — full contract owned by 018

## Affected Tests
- `test/features/drilldown/scan/photo_scan_flow_controller_test.dart` — state machine transitions; bytes cleared on exit
- `test/features/drilldown/scan/photo_scan_dochash_test.dart` — doc-hash miss vs hit + user-proceed / user-cancel
- `test/features/drilldown/scan/photo_scan_imported_source_test.dart` — ImportedSource row written only on confirm; correct counts
- `test/features/drilldown/scan/photo_scan_multi_test.dart` — "Scan another" produces a second `ImportedSource` and additional line-items on the same transaction

## Fixtures Needed
No — synthetic tiny JPEGs (via `image` package) built inline; OCR + parser are mocked in this ticket's tests.

## Refinement Tokens (estimate)
- Input: ~11k tokens
- Output: ~4k tokens

## Token Usage
_Filled after Done._
