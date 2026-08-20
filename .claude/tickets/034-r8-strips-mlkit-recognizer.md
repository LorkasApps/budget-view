# Release build cannot read receipts: R8 strips the ML Kit recognizer

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | Setup |
| **Domain** | Infra |
| **Blocked By** | None |
| **Severity** | Critical |
| **Status** | Done |

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

## Resolved during refinement
The cause was narrowed by experiment, not by reading:

| Step | Result |
|------|--------|
| Dropped `getDefaultProguardFile("proguard-android-optimize.txt")`, kept only our rules | still failed — the aggressive default rules were **not** the cause |
| Added `-keep` for `com.google.mlkit.**`, `com.google.android.odml.**` and both plugin packages | recognition works in the release APK |

So the defect was never the absent script classes: a class that is never loaded does not disturb Android, verification is
lazy. R8 was **renaming ML Kit's own task and handler machinery**, which the recognizer reaches reflectively, and the
native call then returned null. The `-dontwarn` lines from 030 stay — they are still what lets R8 finish — but they were
never the fix.

- **Keep scope** → accepted broad (`com.google.mlkit.**` plus ODML plus the two plugin packages) rather than narrowed by
  trial. Narrowing would cost a device round per attempt to save shrinking on a library whose bundled models dominate the
  APK anyway. The optimize default file stays out: it is not needed, and re-adding it would invite the same class of
  failure back
- **Gate limitation** → recorded in `errors.md` rather than automated: `make release-check` proves the build completes,
  which it did while OCR was broken. A build that runs is not a build that works, and nothing short of an instrumented
  device test can close that gap. Ticket 036 therefore requires each area to be walked on a release APK, not only on
  `make run`
- **Same risk elsewhere** → open, deliberately not chased here: `image_picker`, `file_selector`, Isar's native libs and
  Syncfusion all cross into native code and none has been exercised in a release build. 036's release-APK requirement is
  what will surface them

## Acceptance Criteria
- [x] The release APK recognises text from a receipt, verified on the device with the same image that failed
- [x] `-keep` rules for `com.google.mlkit.**`, `com.google.android.odml.**`, `com.google_mlkit_commons.**` and
      `com.google_mlkit_text_recognition.**` live in `android/app/proguard-rules.pro`
- [x] The `-dontwarn` lines for the four unused script packages remain, so R8 still completes
- [x] `getDefaultProguardFile("proguard-android-optimize.txt")` is gone from the release buildType — it was ruled out as
      the cause and is not needed
- [x] `errors.md` names the real cause and the real fix, replacing the entry that recommended `-dontwarn`
- [x] Signing config untouched; still the debug key

## Affected Tests
None possible in the test VM: ML Kit has no binding there, and R8 does not run for tests. Verification is a release APK
on a device.

## Fixtures Needed
No.

### Refinement Tokens (estimate)
- Input: ~14k tokens
- Output: ~2k tokens

### Implementation Tokens (estimate)
- Input: ~10k tokens
- Output: ~1k tokens
