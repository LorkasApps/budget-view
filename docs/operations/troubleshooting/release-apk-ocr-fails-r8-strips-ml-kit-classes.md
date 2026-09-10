---
title: Release APK OCR fails because R8 strips ML Kit classes
date: 2026-09-10
tags:
  - troubleshooting
description: Release APK OCR fails at runtime or the R8 minify step fails at build time because R8 renames or drops ML Kit classes the recognizer reaches reflectively.
---

# Release APK OCR fails because R8 strips ML Kit classes

## Symptom

Two related failures, both release-build-only:

- Release APK fails OCR with `PlatformException … null object reference` (often via
  `dispatchHandlerMessageImpl`) while debug works.
- The release build dies in `:app:minifyReleaseWithR8` with
  `Missing class com.google.mlkit.vision.text.chinese/devanagari/japanese/korean…`.

## Impact

The runtime variant silently breaks OCR in a shipped release build while debug looks fine; the
build-time variant blocks the release build entirely at the R8 step.

## Likely cause

Two separate things. The **build** failure is the plugin dispatching over scripts this app does
not bundle (Latin only, ticket 017). The **runtime** failure is R8 renaming ML Kit's own
task/handler machinery, which the recognizer reaches reflectively — the absent script classes are
harmless, since a class that is never loaded is never verified.

## Diagnosis

Distinguish the two failures by where they occur: a build-time failure surfaces as an R8 error
naming a missing script class (`chinese`/`devanagari`/`japanese`/`korean`); a runtime failure
surfaces as a `PlatformException … null object reference` in a release APK that OCRs fine in
debug. Note `make release-check` cannot catch the runtime variant — it proves the build completes,
not that OCR works.

## Fix

Both belong in `android/app/proguard-rules.pro`: `-dontwarn` for the four unused script packages
so R8 finishes, **plus** `-keep class com.google.mlkit.** { *; }`, `com.google.android.odml.**`
and both plugin packages so nothing gets renamed. Do **not** add
`proguard-android-optimize.txt` — ruled out as a cause and unnecessary.

## Prevention

After any `proguard-rules.pro` change touching ML Kit, verify OCR on an actual release APK, not
just `make release-check` — the check only proves the build completes, not that OCR works at
runtime.

## Escalation

No owner or on-call for this single-developer project. Reproduce with `make release-check` for the
build-time variant; for the runtime variant, install the built release APK and run OCR on it
directly.
