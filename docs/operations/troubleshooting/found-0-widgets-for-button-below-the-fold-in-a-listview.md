---
title: Found 0 widgets for a button below the fold in a ListView
date: 2026-09-10
tags:
  - troubleshooting
description: find.byType finds 0 widgets because the target sits below the fold of the default 800x600 test surface inside a lazy ListView.
---

# Found 0 widgets for a button below the fold in a ListView

## Symptom

`Found 0 widgets with type "X"` for a button that is plainly in the build method.

## Impact

Fails the test assertion even though the widget exists in source, which can be mistaken for a real
missing-widget bug.

## Likely cause

The test surface is `800x600` and the widget sits inside a `ListView` below the fold. Lazy lists
do not build off-screen children, so it does not exist in the tree.

## Diagnosis

Check whether the target widget's parent is a lazy list (e.g. `ListView.builder`) and whether the
default `800x600` test surface is large enough to place it in the built viewport — lazy lists
never build off-screen children, so `find.byType` legitimately returns nothing even though the
widget exists in source.

## Fix

Enlarge the surface in the test:
`tester.view.physicalSize = const Size(1200, 2400); tester.view.devicePixelRatio = 1.0; addTearDown(tester.view.reset);`.
More robust than `scrollUntilVisible`, which can fail on its own.

## Prevention

Default new widget tests that render long or unbounded lists to the enlarged surface from the
start, rather than discovering the below-the-fold failure later.

## Escalation

No owner or on-call for this single-developer project. Reproduce with
`make test-file FILE=<path>`; if a widget inside a `ListView` is reported missing, enlarge the test
surface per the Fix above before assuming the widget is genuinely absent.
