---
title: flutter analyze fails on info-severity findings
date: 2026-09-10
tags:
  - troubleshooting
description: flutter analyze exits non-zero on info-severity findings like unnecessary_import, aborting make check before tests run.
---

# flutter analyze fails on info-severity findings

## Symptom

`flutter analyze` fails with only `info` findings; `make check` aborts before tests run.

## Impact

Blocks `make check` entirely — tests never run because the gate stops at the analyze step.

## Likely cause

`flutter analyze` exits non-zero on `info` severity too, e.g. `unnecessary_import`.

## Diagnosis

Read the finding — `test_summary.py` reports `info`-level findings by default, so the specific
lint id (for example `unnecessary_import`) is visible in that output rather than hidden.

## Fix

Usually an import already provided by another (`dart:typed_data` vs
`package:flutter/foundation.dart`) — remove the redundant import.

## Prevention

Not established. The source note recorded only the symptom, the cause and the fix; it did not
describe a practice that avoids the redundant-import pattern going forward.

## Escalation

No owner or on-call for this single-developer project. Reproduce with `make check` (or
`./.claude/helper/check.py` directly) and read the `info`-level finding it prints to identify the
specific lint id and file.
