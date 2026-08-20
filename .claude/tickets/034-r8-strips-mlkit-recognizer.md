# Release build cannot read receipts: R8 strips the ML Kit recognizer

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | Setup |
| **Domain** | Infra |
| **Blocked By** | None |
| **Severity** | Critical |
| **Status** | Draft |

## Description
Ticket 030 unblocked the release build with `-dontwarn` rules for the ML Kit script recognizers this app does not bundle.
That silenced R8 but protected nothing: `-dontwarn` only suppresses the warning, it does not keep the classes. The
shrinker is still free to remove them, and the plugin picks its recognizer at runtime through those very script option
classes.

Result: the release APK builds, ships, installs — and OCR fails on the device with
`PlatformException … null object reference`. The same receipt, same gallery image, works in a debug build.

This is a regression introduced by 030, not a pre-existing gap. The rejected alternative there — pulling in the four
ML Kit script artifacts — would have prevented it.

## Repro Steps
1. `make build-apk && make install-apk`
2. Open a booking → `Kassenbon scannen` → gallery path → pick a receipt photo
3. Text recognition fails with `PlatformException` (null object reference)
4. `make run` (debug), repeat step 2 with the same image → recognition succeeds

## Expected vs Actual
- **Expected:** the release build recognises text exactly as the debug build does
- **Actual:** release fails at the native call; debug works

## Affected Envs
`prod` shape (release APK) only. Debug unaffected, which is why `make check` and the whole device pass on `make run`
looked clean.

## Workaround
Use a debug build for anything involving the scan. Not acceptable for a shipped app.

## Since When
Since ticket 030 (2026-08-20). Before that the release build did not complete at all, so no working release ever existed.

## Open questions for refinement
- **Which fix:** real `-keep` rules for the ML Kit and plugin classes, or adding the four script artifacts as
  dependencies (the option 030 rejected on APK size), or narrowing minification for this package?
- If keep rules: which surface exactly — `com.google.mlkit.vision.text.**`, the plugin's own
  `com.google_mlkit_text_recognition.**`, or both? A too-broad `-keep` gives back the size that shrinking bought
- **How does this get caught next time?** `make release-check` proves the build completes, which is exactly what it did
  here. A build that runs is not a build that works — the gate needs a runtime step, or the ticket has to say plainly
  that release OCR is device-verified only
- Does anything else in the app reach native code through reflection and sit behind the same silent risk
  (`image_picker`, `file_selector`, Isar's native libs, Syncfusion)?

## Acceptance Criteria
_Not refined yet — the questions above come first._

## Affected Tests
None possible in the test VM: ML Kit has no binding there, and R8 does not run for tests. Verification is a release APK
on a device.

## Fixtures Needed
No.

## Token Usage
_Filled after Done._
