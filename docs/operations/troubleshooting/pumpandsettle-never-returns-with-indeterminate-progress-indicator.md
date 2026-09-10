---
title: pumpAndSettle() never returns with an indeterminate progress indicator
date: 2026-09-10
tags:
  - troubleshooting
description: pumpAndSettle() hangs because an indeterminate progress indicator schedules frames forever.
---

# pumpAndSettle() never returns with an indeterminate progress indicator

## Symptom

`pumpAndSettle()` never returns.

## Impact

Blocks the widget test that calls it — the test run stalls until killed, so `make check` cannot
complete.

## Likely cause

An indeterminate `LinearProgressIndicator` / `CircularProgressIndicator` is on screen; it schedules
frames forever, so "no pending frames" never holds.

## Diagnosis

Not established. The source note recorded only the symptom, the cause and the fix.

## Fix

Pump bounded frames instead: `for (…) await tester.pump(const Duration(milliseconds: 50));`

## Prevention

Whenever a test can render an indeterminate progress indicator, use a bounded `pump` loop instead
of `pumpAndSettle` from the start — this avoids the hang rather than debugging it after the fact.
See also
[pushed screen still findsOneWidget after tester.pageBack()](pushed-screen-still-findsonewidget-after-tester-pageback.md),
which pumps bounded frames around route transitions for a related reason but explicitly warns
against reaching for `pumpAndSettle` there.

## Escalation

No owner or on-call for this single-developer project. Reproduce with
`make test-file FILE=<path>`; if it stalls, check the widget tree for an indeterminate progress
indicator and replace `pumpAndSettle()` with a bounded pump loop per the Fix above.
