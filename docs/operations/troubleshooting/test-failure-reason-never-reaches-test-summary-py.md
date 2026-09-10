---
title: A test failure's reason never reaches test_summary.py
date: 2026-09-10
tags:
  - troubleshooting
description: test_summary.py reports a failure with no reason because flutter test writes exception dumps to stderr and hand-copied output gets truncated.
---

# A test failure's reason never reaches test_summary.py

## Symptom

A failure's reason never reaches `test_summary.py`.

## Impact

Hides the actual cause of a red run behind a bare pass/fail, making the failure look
unactionable.

## Likely cause

Two separate causes: `flutter test` writes exception dumps to stderr, and long output gets
truncated when copied by hand.

## Diagnosis

If `test_summary.py` reports a failure with no reason, read `.claude/tmp/check.log` directly — it
holds the full output, including stderr, that hand-copying or the summary can drop.

## Fix

Run `./.claude/helper/check.py` instead of piping by hand: it keeps the full output at
`.claude/tmp/check.log`, which the agent can read. A `tee "$TMPDIR/…"` cannot substitute for this —
the shell's `$TMPDIR` differs from the agent's.

## Prevention

Always run `./.claude/helper/check.py` rather than piping `flutter test` output by hand, so the
full stderr output is captured in `.claude/tmp/check.log` instead of being silently dropped.

## Escalation

No owner or on-call for this single-developer project. Reproduce with `make check`, then read
`.claude/tmp/check.log` for the full output rather than relying on a hand-copied summary.
