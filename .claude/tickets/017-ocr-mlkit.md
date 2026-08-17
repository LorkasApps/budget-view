# OCR via Google ML Kit

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | 016 |
| **Status** | Ready |

## Description
On-device OCR via Google ML Kit Text Recognition (Latin script — covers German Umlauts). Called from the scan flow (ticket 016) with raw JPEG/PNG bytes. Returns a structured `OcrResult` with block/line/word positions so ticket 018 can reason about layout. **No persistence** — the result lives in memory for the duration of the flow, then is discarded together with the source bytes.

The `OcrService` interface and `OcrResult` type already exist at `lib/features/drilldown/scan/domain/ocr_service.dart`, with a `NoOcrService` stub. This ticket replaces the implementation only, not the contract. Wire through `ocrServiceProvider` in `photo_scan_providers.dart`.

## Types

```dart
class OcrResult {
  final String fullText;              // best-effort concatenation for debug / manual entry
  final List<OcrBlock> blocks;
}

class OcrBlock {
  final String text;
  final Rect boundingBox;
  final List<OcrLine> lines;
}

class OcrLine {
  final String text;
  final Rect boundingBox;
  // optional (per ML Kit): confidence, corner points — include if easy, otherwise omit
}
```

## Service

```dart
abstract class OcrService {
  /// Returns [OcrResult]. Throws [OcrEmptyException] when no meaningful text is detected.
  /// Throws [OcrEngineException] on ML Kit internal failure.
  Future<OcrResult> recognize(Uint8List bytes);
}
```

## Acceptance Criteria
- [ ] `google_mlkit_text_recognition` dependency added
- [ ] Android manifest: `<meta-data android:name="com.google.mlkit.vision.DEPENDENCIES" android:value="ocr" />` added under `<application>` so the model bundles with the app
- [ ] `MlKitOcrService` concrete impl in `lib/features/drilldown/scan/ocr/mlkit_ocr_service.dart` — invokes `TextRecognizer` (default Latin), returns `OcrResult`
- [ ] `ocrServiceProvider` (Riverpod) exposes service, overridable in tests
- [ ] `MlKitOcrService.recognize`:
  - Wraps ML Kit calls in try/catch → `OcrEngineException` on failure
  - Considers a result "empty" if `fullText.trim().isEmpty` OR `blocks.isEmpty` OR only 1-2 characters recognized → throws `OcrEmptyException`
- [ ] Consumer (`PhotoScanFlowController` from 016) catches:
  - `OcrEmptyException` → shows modal "Kein Text erkannt." with buttons `Retry (neues Foto)` / `Abbrechen`
  - `OcrEngineException` → shows modal "OCR-Fehler: <message>" with same options
- [ ] German-specific verification: unit test with a synthetic image containing `Käse, Öl, Süß, Brühe` — result includes all four with correct Umlauts
- [ ] No result is written to any persistent store — service returns to caller only
- [ ] Recognizer instance is closed (`recognizer.close()`) after each call to release native memory (or long-lived + closed on service disposal — pick whichever ML Kit recommends; document choice inline)

## Test Strategy
- Mock `TextRecognizer` at the plugin boundary for pure unit tests (dependency-inject a factory)
- One end-to-end test with a synthetic image (generated in test via `image` package) to smoke-test the full path — kept minimal to avoid flakiness

## Affected Tests
- `test/features/drilldown/scan/ocr/mlkit_ocr_service_test.dart` — success, empty, engine-error paths (mocked)
- `test/features/drilldown/scan/ocr/mlkit_ocr_umlauts_test.dart` — synthetic-image round-trip (may be marked `@Skip` in CI if flaky, run locally)

## Fixtures Needed
No — synthetic images built inline.

## Refinement Tokens (estimate)
- Input: ~9k tokens
- Output: ~3k tokens

## Token Usage
_Filled after Done._
