---
title: Troubleshooting
date: 2026-09-10
description: One page per symptom already diagnosed once, so it is not diagnosed twice.
---

# Troubleshooting

One page per symptom, titled after what the reader sees plus the system term that makes it
searchable. Several messages sharing one root cause belong on one page.

Each page follows the same seven sections: Symptom, Impact, Likely cause, Diagnosis, Fix,
Prevention, Escalation. Where a section is not known it says so — a guessed cause is worse than an
admitted gap, because the next reader acts on it.

| Page | Symptom | Root cause |
|------|---------|------------|
| [flutter-test-hangs-on-testwidgets-with-isar.md](flutter-test-hangs-on-testwidgets-with-isar.md) | `flutter test` hangs forever on a `testWidgets` file | Isar I/O never completes inside the fake-async widget test zone |
| [pumpandsettle-never-returns-with-indeterminate-progress-indicator.md](pumpandsettle-never-returns-with-indeterminate-progress-indicator.md) | `pumpAndSettle()` never returns | An indeterminate progress indicator schedules frames forever |
| [flutter-analyze-fails-on-info-severity-findings.md](flutter-analyze-fails-on-info-severity-findings.md) | `flutter analyze` fails with only `info` findings | `flutter analyze` exits non-zero on `info` severity too |
| [dropdownbuttonformfield-asserts-on-build-with-invalid-initialvalue.md](dropdownbuttonformfield-asserts-on-build-with-invalid-initialvalue.md) | `DropdownButtonFormField` asserts on build | `initialValue` has no matching entry in `items` |
| [syncfusion-pdftextextractor-label-match-fails-on-visible-text.md](syncfusion-pdftextextractor-label-match-fails-on-visible-text.md) | Syncfusion text extraction label match fails although the text is visible | `PdfTextExtractor` drops parentheses and pads `TextWord.text` with spaces |
| [ambiguous-import-on-category-from-flutter-foundation.md](ambiguous-import-on-category-from-flutter-foundation.md) | `ambiguous_import` on an entity named `Category` | `flutter/foundation.dart` exports its own `Category` annotation |
| [widget-tests-fail-with-renderflex-overflow-in-listtile-leading.md](widget-tests-fail-with-renderflex-overflow-in-listtile-leading.md) | Every widget test in a file fails | A `RenderFlex` overflow in a `ListTile.leading` rendered by every test |
| [found-0-widgets-for-button-below-the-fold-in-a-listview.md](found-0-widgets-for-button-below-the-fold-in-a-listview.md) | `Found 0 widgets with type "X"` for a button plainly in the build method | The widget sits below the fold of the `800x600` test surface inside a lazy `ListView` |
| [isar-collection-getter-not-defined-missing-entity-import.md](isar-collection-getter-not-defined-missing-entity-import.md) | `The getter '...' isn't defined for the type 'Isar'` | The collection getter extension is generated into the entity's `.g.dart`, not pulled in by a repository or `isar_provider.dart` import |
| [pushed-screen-still-findsonewidget-after-tester-pageback.md](pushed-screen-still-findsonewidget-after-tester-pageback.md) | A pushed screen is still `findsOneWidget` after `tester.pageBack()` | The route's reverse transition had not finished pumping |
| [release-apk-ocr-fails-r8-strips-ml-kit-classes.md](release-apk-ocr-fails-r8-strips-ml-kit-classes.md) | Release APK OCR fails at runtime, or `:app:minifyReleaseWithR8` fails at build time | R8 strips or renames ML Kit classes reached reflectively by the recognizer |
| [test-failure-reason-never-reaches-test-summary-py.md](test-failure-reason-never-reaches-test-summary-py.md) | A failure's reason never reaches `test_summary.py` | `flutter test` writes exception dumps to stderr, and hand-copied output gets truncated |
| [dismissible-never-fires-confirmdismiss-in-widget-test.md](dismissible-never-fires-confirmdismiss-in-widget-test.md) | A `Dismissible` never fires `confirmDismiss` in a widget test | A fixed-distance drag sits just over the `40 %` width threshold and fixed pumps miss the dialog transition |
| [fake-repository-compiles-but-suite-fails-with-type-error.md](fake-repository-compiles-but-suite-fails-with-type-error.md) | A fake repository compiles in the editor but the suite fails with a type error | The fake's method signature differs from the real repository it implements |
| [dart-heredoc-produces-non-bool-condition-and-expected-token-errors.md](dart-heredoc-produces-non-bool-condition-and-expected-token-errors.md) | Dart written through a shell heredoc produces `non_bool_condition` and `expected_token` errors | zsh escapes `\!` inside a quoted heredoc |
| [appended-enum-value-reads-back-as-first-value-in-isar.md](appended-enum-value-reads-back-as-first-value-in-isar.md) | A newly appended `@enumerated` value reads back as the first value | Isar's generated `.g.dart` index table was not regenerated after the enum changed |
