# Kassenbon photo capture (ephemeral)

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | 015, 009 |
| **Status** | Done |

## Description
Capture receipt photos (camera or gallery) for a specific `Transaction`. **Photos are ephemeral** — bytes live only in memory during the scan flow, are passed to OCR (ticket 017) and line-item parsing (ticket 018), then discarded. No file storage, no `Receipt` entity.

Multiple photos per transaction supported: user scans them sequentially, each photo flows through capture → doc-hash-check → OCR → line-item extraction → add to the transaction's line-items. Doc-hash check (ticket 009) prevents re-scanning the same photo.

### Known limitation
If `LineItemRepository.save()` rejects a candidate mid-`confirm()`, earlier candidates stay persisted, no `ImportedSource` row is written, and the Restposten row stays stale — the reconcile call sits behind the loop. No cross-repository transaction exists to roll it back. Ticket 018's review step validates all candidates before returning, which keeps the case unreachable in practice.

## Re-verify after blockers 015 + 009 (2026-08-14)
Four drifts resolved before start:

1. **OCR/Parser existieren noch nicht** (017/018 kommen nach 016). 016 besitzt beide Interfaces und liefert je eine Stub-Implementierung, die ein leeres Ergebnis zurückgibt; die State-Machine läuft vollständig durch. 017/018 tauschen nur die Impl, der Controller bleibt unberührt.
2. **Kein Transaction-Detail-Screen** (Entscheidung #50 bleibt gültig). Einstieg = Button in `LineItemsSection` innerhalb `TransactionFormScreen` (Edit-Modus), neben `+ Position`. Der Scan-Flow ist komplett modal, braucht also keine eigene Screen-Fläche.
3. **Live-Count "line-items from scans" gestrichen.** Weder `LineItem` noch `ImportedSource` trägt Provenance, und ein informativer Zähler rechtfertigt kein Schema-Feld. Falls Provenance gewollt ist, gehört sie in 018, wo die Zeilen entstehen.
4. **Keine Android-Runtime-Permissions.** `image_picker` 1.2.3 nutzt ab API 33 den Android Photo Picker und für die Kamera einen `ACTION_IMAGE_CAPTURE`-Intent — beides ohne Manifest-Eintrag. Ein deklariertes `CAMERA` würde die Runtime-Abfrage erst erzeugen.

## Flow

```
[LineItemsSection (booking form, edit mode): "Kassenbon scannen"]
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
- [x] `image_picker` ^1.2.3 dependency added (`path_provider` already present since ticket 002)
- [x] `image` ^4.9.1 dependency added — used only for optional in-memory resize before OCR (max 2000 px longer side, JPEG quality 85) to keep OCR fast
- [x] No Android manifest permission and no runtime permission request — Photo Picker + camera intent cover both paths
- [x] `LineItemsSection` (TransactionFormScreen, edit mode): "Scan Kassenbon" button next to `+ Position`; **no photo grid, no scan counter**
- [x] "Scan Kassenbon" opens the capture flow above
- [x] `OcrService` + `ReceiptLineItemParser` interfaces defined here, each with a stub implementation returning an empty result (017 / 018 replace the impl, not the contract)
- [x] Camera / Gallery source picker bottom sheet
- [x] `PhotoScanFlowController` (Riverpod `AutoDisposeNotifier`, the project's current pattern — the PDF import flow uses the same) holds bytes in memory, orchestrates the flow, exposes state (idle, capturing, hashing, duplicateWarning, recognizing, parsing, awaitingConfirm, persisting, done, cancelled, failed)
- [x] Controller **clears** bytes reference on any exit path (confirm, cancel, error)
- [x] Doc-hash check integrates ticket 009's `duplicateCheckerProvider.findDocumentMatches(hash)` — if match, show modal with previous-import summary + Proceed/Cancel
- [x] After user confirms line-items: one `ImportedSource` row created (`kind=photo`, hash, filename may be empty for camera captures, `lineItemsProduced=N`, `transactionsProduced=0`)
- [x] "Scan another" restarts the flow within the same transaction detail (fresh capture, new hash, new pass)
- [x] Cancel at any step: bytes discarded, no `ImportedSource` row, transaction unchanged
- [x] Our code writes no path to disk; `image_picker` keeps a plugin-owned temp file for camera captures

## Handoff Contracts
- **To ticket 017 (OCR):** `OcrService.recognize(Uint8List bytes) → Future<OcrResult>` — full contract owned by 017; this ticket only calls it
- **To ticket 018 (line-item parsing):** `ReceiptLineItemParser.parse(OcrResult, transactionSign) → List<LineItemCandidate>` — full contract owned by 018

## Affected Tests
- `test/features/drilldown/scan/domain/photo_scan_flow_controller_test.dart` — state machine transitions; bytes cleared on exit
- `test/features/drilldown/scan/domain/photo_scan_dochash_test.dart` — doc-hash miss vs hit + user-proceed / user-cancel
- `test/features/drilldown/scan/domain/photo_scan_imported_source_test.dart` — ImportedSource row written only on confirm; correct counts
- `test/features/drilldown/scan/domain/photo_scan_multi_test.dart` — "Scan another" produces a second `ImportedSource` and additional line-items on the same transaction
- `test/features/drilldown/scan/domain/scan_test_support.dart` — shared fakes and fixtures

## Fixtures Needed
No — the tests fake the image source, the preprocessor, OCR and the parser, so plain byte lists suffice; no JPEG has to be synthesized and `compute` stays out of the test run.

## Refinement Tokens (estimate)
- Input: ~11k tokens
- Output: ~4k tokens

### Implementation Tokens (estimate)
- Input: ~95k
- Output: ~14k
