---
title: DropdownButtonFormField asserts on build with an invalid initialValue
date: 2026-09-10
tags:
  - troubleshooting
description: DropdownButtonFormField asserts on build because initialValue has no matching entry in items.
---

# DropdownButtonFormField asserts on build with an invalid initialValue

## Symptom

`DropdownButtonFormField` asserts on build.

## Impact

Crashes the widget at build time — any screen containing the dropdown becomes unusable until
fixed.

## Likely cause

`initialValue` has no matching entry in `items`.

## Diagnosis

Not established. The source note recorded only the symptom, the cause and the fix.

## Fix

Ensure the selected uuid exists in the list, or pass `null`. Note this Flutter version uses
`initialValue`, not the deprecated `value`.

## Prevention

Not established beyond the fix itself. The source note did not separate a preventive practice
(e.g. how to keep a selection valid when its backing list changes) from the one-time resolution.

## Escalation

No owner or on-call for this single-developer project. Reproduce by building the affected screen;
the assertion names the widget. Check that the id passed as `initialValue` still exists in the
`items` list, or pass `null`.
