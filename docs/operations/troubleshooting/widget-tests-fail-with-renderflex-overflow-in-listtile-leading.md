---
title: Widget tests fail with a RenderFlex overflow in ListTile.leading
date: 2026-09-10
tags:
  - troubleshooting
description: Every widget test in a file fails because a fixed-size SizedBox in ListTile.leading overflows the widgets it holds.
---

# Widget tests fail with a RenderFlex overflow in ListTile.leading

## Symptom

Every widget test in a file fails with `Test failed. See exception logs above.`

## Impact

Fails an entire test file at once, which can look like sixteen independent test bugs when it is
one shared layout bug.

## Likely cause

A `RenderFlex` overflow in a row that all tests render — e.g. a `ListTile.leading` given a fixed
`SizedBox(width: 64)` holding a 48px `IconButton` plus a 24px `Icon`.

## Diagnosis

Read the full exception log above the failure line, not just the summary — every test in the file
fails with the same `RenderFlex overflowed` message pointing at the same widget's `leading` slot,
confirming one shared layout bug rather than many independent test failures.

## Fix

Do not hand-compute widths inside `leading`. Put one widget there and move extras into `title`
with an `Expanded` text.

## Prevention

Not established beyond the fix itself. The source note did not describe a general layout practice
for `ListTile.leading` beyond the specific resolution.

## Escalation

No owner or on-call for this single-developer project. Reproduce with
`make test-file FILE=<path>`; read the exception log for the `RenderFlex overflowed` message and
the widget it names.
