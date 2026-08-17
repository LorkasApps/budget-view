# OCR via Google ML Kit

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | 016 |
| **Status** | Done |

## Description
On-device OCR via Google ML Kit Text Recognition (Latin script — covers German Umlauts). Called from the scan flow (ticket 016) with raw JPEG/PNG bytes. Returns a structured `OcrResult` with block/line/word positions so ticket 018 can reason about layout. **No persistence** — the result lives in memory for the duration of the flow, then is discarded together with the source bytes.

The `OcrService` interface and `OcrResult` type already exist at `lib/features/drilldown/scan/domain/ocr_service.dart`, with a `NoOcrService` stub. This ticket replaces the implementation only, not the contract. Wire through `ocrServiceProvider` in `photo_scan_providers.dart`.

## Re-verify after blocker 016 (2026-08-17)
Four conflicts with what 016 actually shipped, resolved before start:

1. **`OcrResult` grows layout instead of staying flat.** 016 shipped `OcrResult({List<String> lines})`; this ticket replaces it with the shape below. Receipt heuristics live on x-positions (prices right-aligned, quantities left, discounts indented) — the same lesson as the ING decision of 2026-08-11, which derives columns from coordinates rather than text patterns. ML Kit hands the boxes over for free; dropping them would be expensive to undo. Breaks the contract 016 wrote, so `NoOcrService` and the test fakes move with it.
2. **No `OcrEmptyException`.** In 016 a zero-position pass is legitimate and already has a dialog ("Keine Positionen erkannt … der Scan wird nur vermerkt"). An empty result therefore flows through untouched. Only `OcrEngineException` is introduced, for a genuinely broken engine, and it surfaces through the controller's existing `failed` phase. A retry loop belongs to 018, which builds the review surface anyway.
3. **ML Kit cannot take JPEG bytes.** `InputImage.fromBytes` wants raw NV21 plus rotation on Android; only `fromFilePath` / `fromFile` accept an encoded image. The service therefore writes the already-downscaled bytes to a temp file in the cache dir, recognizes from that path, and deletes it in a `finally`. The alternatives were owning YUV conversion *and* EXIF rotation in Dart (a wrong result reads as garbage text, not as a crash) or leaning on `image_picker`'s plugin-owned temp file (foreign lifetime, and the downscale would go to waste). 016's doc line "our code writes no path to disk" is corrected rather than circumvented — the file is transient, not persisted.
4. **No automated proof that ML Kit reads German.** The plugin has no binding in the test VM. Only our own seams are unit-tested (temp-file lifecycle, mapping, error wrapping); a synthetically rendered image would exercise a path the app never takes, same reasoning as the "no fixture PDFs" decision. The device check for umlauts moved to **018**: this ticket ships no surface that displays recognized text, and 018's preview is exactly that surface.

## Types

```dart
class OcrResult {
  final String fullText;              // ML Kit's own concatenation
  final List<OcrBlock> blocks;
  bool get isEmpty => blocks.isEmpty;
}

class OcrBlock {
  final String text;
  final Rect boundingBox;
  final List<OcrLine> lines;
}

class OcrLine {
  final String text;
  final Rect boundingBox;
  final double? confidence;           // ML Kit supplies it per line, kept as-is
}
```

## Service

```dart
abstract interface class OcrService {
  /// Empty results are legal and travel on. Throws [OcrEngineException] when
  /// ML Kit itself fails.
  Future<OcrResult> recognize(Uint8List bytes);
}
```

## Acceptance Criteria
- [x] `google_mlkit_text_recognition` ^0.16.0 dependency added
- [x] Android manifest: `<meta-data android:name="com.google.mlkit.vision.DEPENDENCIES" android:value="ocr" />` under `<application>`, so the model ships with the app instead of being downloaded on first use
- [x] `OcrResult` / `OcrBlock` / `OcrLine` replace the flat `lines` shape; `NoOcrService` and the fakes in `test/features/drilldown/scan/domain/scan_test_support.dart` follow
- [x] `OcrEngineException` (German, user-facing `message`) added next to the contract
- [x] `MlKitOcrService` in `lib/features/drilldown/scan/data/mlkit_ocr_service.dart` — matches 016's `domain/` (contracts) vs `data/` (implementations) split, not the `scan/ocr/` path this ticket originally named
- [x] Recognition path: prepared bytes → temp file in the cache dir (`path_provider`, directory injectable for tests) → `InputImage.fromFilePath` → `TextRecognizer` (Latin script)
- [x] Temp file deleted in a `finally`, including when ML Kit throws
- [x] `TextRecognizer` instance is long-lived per service and closed via `ref.onDispose` on `ocrServiceProvider` — ML Kit's own guidance, one native allocation instead of one per photo
- [x] Every ML Kit failure is wrapped in `OcrEngineException`; the controller's existing `failed` phase surfaces its message (`_fail` unwraps it like `LineItemInvalid`)
- [x] An empty result throws nothing — it reaches `awaitingConfirm` with zero candidates, as 016 established
- [x] `ocrServiceProvider` yields `MlKitOcrService`, still overridable in tests
- [x] No result is written to any store — the service returns to its caller only

## Test Strategy
Unit tests cover what we own. The plugin call sits behind a `MlKitTextReader` port; a hand-written fake returns `RecognizedText` / `TextBlock` / `TextLine` built through their public constructors, so the mapping is verified without the native binding. The temp directory is injected, so the file lifecycle is assertable. Real recognition is a device check, per the re-verify note.

## Affected Tests
- `test/features/drilldown/scan/data/mlkit_ocr_service_test.dart` — mapping (blocks, lines, boxes, confidence, `fullText`), empty result travels on, engine failure becomes `OcrEngineException`, temp file written then deleted on both the success and the throwing path
- `test/features/drilldown/scan/domain/scan_test_support.dart` — fake OCR service updated to the new result shape

## Fixtures Needed
No — `RecognizedText` and friends are constructed inline in the tests.

## Refinement Tokens (estimate)
- Input: ~9k tokens
- Output: ~3k tokens

### Implementation Tokens (estimate)
- Input: ~70k tokens
- Output: ~11k tokens
