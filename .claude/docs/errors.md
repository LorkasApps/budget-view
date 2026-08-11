# Known Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `flutter test` hangs forever on a `testWidgets` file, `--timeout` never fires, only ^C stops it | The test body runs in a fake-async zone where real I/O (Isar open/query/write) never completes. `tester.runAsync` does **not** rescue it once widgets and Isar are mixed. | Keep Isar out of `testWidgets`. Override the data providers with pure Dart (`accountsProvider(false).overrideWith((ref) => Stream.value([...]))`) and cover persistence in a plain `test()` instead, which runs outside the widget zone. |
| `pumpAndSettle()` never returns | An indeterminate `LinearProgressIndicator` / `CircularProgressIndicator` is on screen; it schedules frames forever, so "no pending frames" never holds. | Pump bounded frames: `for (…) await tester.pump(const Duration(milliseconds: 50));` |
| `flutter analyze` fails with only `info` findings, `make check` aborts before tests | `flutter analyze` exits non-zero on `info` severity too, e.g. `unnecessary_import`. | Read the finding — `test_summary.py` reports info by default. Usually an import already provided by another (`dart:typed_data` vs `package:flutter/foundation.dart`). |
| `DropdownButtonFormField` asserts on build | `initialValue` has no matching entry in `items`. | Ensure the selected uuid exists in the list, or pass `null`. Note this Flutter version uses `initialValue`, not the deprecated `value`. |
| Syncfusion text extraction: label match fails although the text is visible in the PDF | `PdfTextExtractor` drops parentheses (`Betrag (EUR)` → `Betrag EUR`) and pads `TextWord.text` with spaces. | Match bare words and `trim()` every word before comparing or joining. |
