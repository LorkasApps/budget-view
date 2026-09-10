---
title: Dismissible never fires confirmDismiss in a widget test
date: 2026-09-10
tags:
  - troubleshooting
description: Dismissible never fires confirmDismiss in a widget test because a plain drag sits just over the 40 percent width threshold and fixed pumps don't carry the dialog transition.
---

# Dismissible never fires confirmDismiss in a widget test

## Symptom

A `Dismissible` never fires `confirmDismiss` in a widget test.

## Impact

Blocks any test asserting on the dismiss-confirmation dialog for that row.

## Likely cause

`tester.drag(finder, Offset(-500, 0))` sits just over the `40 %` width threshold on a `1200 px`
test surface, and fixed `pump` calls do not carry the dialog transition.

## Diagnosis

Not established. The source note recorded only the symptom, the cause and the fix.

## Fix

`await tester.fling(row, const Offset(-800, 0), 2000)` followed by `pumpAndSettle`. Velocity makes
the dismissal fire regardless of distance.

## Prevention

Use `tester.fling` with velocity, not a fixed-distance `tester.drag`, whenever a test needs to
trigger a `Dismissible`'s confirmation dialog — this avoids depending on the exact `40 %` width
threshold.

## Escalation

No owner or on-call for this single-developer project. Reproduce with
`make test-file FILE=<path>`; if `confirmDismiss` never fires, switch the drag to a `fling` with
velocity per the Fix above.
