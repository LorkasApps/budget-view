---
title: flutter test hangs on testWidgets with Isar
date: 2026-09-10
tags:
  - troubleshooting
description: A testWidgets file hangs forever because Isar I/O never completes inside the fake-async widget test zone.
---

# flutter test hangs on testWidgets with Isar

## Symptom

`flutter test` hangs forever on a `testWidgets` file. `--timeout` never fires; only `^C` stops it.

## Impact

Blocks that test file and, in turn, `make check` — the run never terminates on its own, so the
gate cannot pass until the test is restructured.

## Likely cause

The test body runs in a fake-async zone where real I/O (Isar open/query/write) never completes.
`tester.runAsync` does **not** rescue it once widgets and Isar are mixed.

## Diagnosis

Not established. The source note recorded only the symptom, the cause and the fix — no steps for
confirming Isar is the culprit before applying the fix.

## Fix

Keep Isar out of `testWidgets`. Override the data providers with pure Dart
(`accountsProvider(false).overrideWith((ref) => Stream.value([...]))`) and cover persistence in a
plain `test()` instead, which runs outside the widget zone.

## Prevention

Design widget tests so Isar never appears inside `testWidgets` in the first place: fake the data
providers with pure Dart streams/futures, and put any real persistence assertions in a plain
`test()`. This prevents the hang from recurring rather than curing it after the fact.

## Escalation

No owner or on-call for this single-developer project. Reproduce with
`make test-file FILE=<path>`; if it hangs, `^C` and check whether the file overrides Isar-backed
providers per the Fix above. This is also recorded as a standing gotcha in the project's
`CLAUDE.md` ("Isar never completes inside `testWidgets`").
