---
title: Pushed screen is still findsOneWidget after tester.pageBack()
date: 2026-09-10
tags:
  - troubleshooting
description: A pushed screen is still findsOneWidget after tester.pageBack() because the outgoing route's reverse transition had not finished pumping.
---

# Pushed screen is still findsOneWidget after tester.pageBack()

## Symptom

A pushed screen is still `findsOneWidget` after `tester.pageBack()`.

## Impact

Fails navigation assertions in widget tests even though the back action is logically correct,
because the check runs before the transition finishes.

## Likely cause

The route's reverse transition had not finished. 8 × 50 ms of bounded pumps (400 ms) is not enough
— the outgoing route stays mounted until the animation completes.

## Diagnosis

Not established beyond the cause itself. The source note did not describe how to confirm the
transition is still running versus a genuine navigation bug, beyond noting the pump duration was
insufficient.

## Fix

Pump ~24 × 50 ms around route changes. Do **not** reach for `pumpAndSettle` as the fix; it is the
thing that hangs when a screen schedules frames forever — see
[pumpAndSettle() never returns with an indeterminate progress indicator](pumpandsettle-never-returns-with-indeterminate-progress-indicator.md).

## Prevention

Standardize on ~24 × 50 ms of bounded pumps around every route change in widget tests, rather than
a shorter fixed duration, to avoid asserting on a still-transitioning route.

## Escalation

No owner or on-call for this single-developer project. Reproduce with
`make test-file FILE=<path>`; if a widget persists after `pageBack()`, increase the bounded pump
count around the navigation call per the Fix above.
