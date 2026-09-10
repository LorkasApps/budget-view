# Release build fails: R8 misses ML Kit script recognizers

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | Setup |
| **Domain** | Infra |
| **Blocked By** | None |
| **Severity** | High |
| **Status** | Done |

## Description
`flutter build apk --release` (`make build-apk`) fails in `:app:minifyReleaseWithR8`. `google_mlkit_text_recognition`
dispatches over every script its plugin supports, so its Dart-facing `initialize` references the Chinese, Devanagari,
Japanese and Korean recognizer options. We only depend on the Latin recognizer (ticket 017), so those classes are not on
the classpath and R8 refuses to complete.

Debug builds are unaffected — R8 only runs for release, which is why `make check` and every device round so far missed
it.

## Repro Steps
1. `make build-apk` on a clean checkout
2. Build reaches `Running Gradle task 'assembleRelease'`
3. Fails after ~80 s

## Expected vs Actual
- **Expected:** `build/app/outputs/flutter-apk/app-release.apk` is produced
- **Actual:** `ERROR: R8: Missing class com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder` and
  seven more of the same shape, then `Execution failed for task ':app:minifyReleaseWithR8'`

R8 writes the rules it would need to `build/app/outputs/mapping/release/missing_rules.txt`.

## Affected Envs
`dev` (release build on the workstation). No shipped build exists yet, so nothing in the field is broken.

## Workaround
None for a release APK. `make run` / `make run-release` still work, so ticket 028's device pass is not blocked — it runs
off `make run` by its own verification strategy.

## Since When
Since ML Kit arrived with ticket 017 (2026-08-17). It stayed invisible because no release build was attempted until
today, 2026-08-20.

## Resolved during refinement
- **Fix** → a new `android/app/proguard-rules.pro` carrying `-dontwarn` for the unused script packages, wired via
  `proguardFiles` in the release buildType. R8 itself is not ours to switch off: the Flutter Gradle Plugin enables
  shrinking for release, `build.gradle.kts` sets neither `isMinifyEnabled` nor `proguardFiles` today. Rejected pulling
  in the four ML Kit script artifacts (megabytes for recognizers no code path calls, against the Latin-only decision of
  017) and rejected disabling minification (loses shrinking and obfuscation, and would hide the next plugin conflict
  instead of surfacing it). Accepted cost: the rule also silences genuinely missing classes in those packages
- **Rule scope** → four separate lines, one per script package, not a `vision.text.**` wildcard. A wildcard would also
  swallow missing classes of the Latin recognizer we do use, turning an integration error into a runtime surprise on the
  device. Accepted cost: a plugin update that adds a fifth script breaks the build again — which is the wanted reaction,
  because it means a decision is due
- **Regression guard** → a row in `.claude/docs/errors.md` plus a `make release-check` target chaining `check` and
  `build-apk`. `make check` structurally cannot see R8, so the release path needs its own named call rather than being
  discovered broken at delivery time. Accepted cost: `build-apk` takes ~80 s, so this is not a per-commit gate
- **KGP warning in scope** → handled here, not in a follow-up. The warning names `google_mlkit_commons` and
  `google_mlkit_text_recognition`, and it turned out not to depend on upstream goodwill: `google_mlkit_text_recognition`
  0.17.0 (published 2026-08-17) says "Migrate Android plugin build to AGP built-in Kotlin support", and its raised floor
  of Flutter >= 3.44 / Dart ^3.12 is what this project already runs. 0.17.1 only pulls `google_mlkit_commons` ^0.13.0.
  Both fixes touch the same Android build, so one round covers them

## Acceptance Criteria
- [x] `android/app/proguard-rules.pro` exists and carries `-dontwarn` for exactly four packages, one line each:
      `com.google.mlkit.vision.text.chinese.**`, `.devanagari.**`, `.japanese.**`, `.korean.**`
- [x] The release buildType in `android/app/build.gradle.kts` references it through `proguardFiles` alongside
      `getDefaultProguardFile("proguard-android-optimize.txt")`; `isMinifyEnabled` stays unset, since the Flutter Gradle
      Plugin owns shrinking
- [x] `google_mlkit_text_recognition` is at `^0.17.1`, which carries `google_mlkit_commons` `^0.13.0`
- [x] `make build-apk` completes and writes `build/app/outputs/flutter-apk/app-release.apk`
- [x] That build output contains neither the R8 missing-class errors nor the KGP plugin warning
- [x] `make check` is green after the plugin bump — the OCR and scan suites in particular
- [x] `make release-check` runs `check` then `build-apk` and appears in `make help`
- [x] `.claude/docs/errors.md` gains a row: symptom (R8 missing ML Kit script classes), cause (plugin dispatches over
      every script, we ship Latin only), fix (the keep rules)
- [x] Wherever the docs name the ML Kit plugin version, it matches the new one — no doc pins it; only `pubspec.yaml`
      does, and `infrastructure.md` now documents `make release-check` and where the keep rules live
- [x] The signing config is **not** touched — release still signs with the debug key, and a real keystore stays its own
      ticket

## Affected Tests
No new test. R8 runs outside the Dart test VM, so the verification is `make build-apk` completing; the existing OCR and
scan suites guard the plugin bump.

## Fixtures Needed
No.

### Refinement Tokens (estimate)
- Input: ~18k tokens
- Output: ~3k tokens

### Implementation Tokens (estimate)
- Input: ~22k tokens
- Output: ~3k tokens

## Verified
`make get && ./.claude/helper/check.py release-check` on 2026-08-20: 425 tests pass, `app-release.apk` written (98.7 MB), build output free of both the R8 missing-class errors and the KGP warning.
Observation for a possible follow-up, out of scope here: that APK is a universal build carrying every ABI.
