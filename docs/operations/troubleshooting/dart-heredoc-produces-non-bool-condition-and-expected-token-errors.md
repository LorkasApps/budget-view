---
title: Dart code written through a shell heredoc produces non_bool_condition and expected_token errors
date: 2026-09-10
tags:
  - troubleshooting
description: Dart written through a zsh heredoc produces non_bool_condition and expected_token errors because zsh escapes ! inside the quoted heredoc.
---

# Dart code written through a shell heredoc produces non_bool_condition and expected_token errors

## Symptom

Dart code written through a shell heredoc compiles with `non_bool_condition` and `expected_token`
at a line containing `\!`.

## Impact

Corrupts the written Dart file at every `!` operator, producing analyzer errors that point at the
wrong cause (the file's logic, not the shell that wrote it).

## Likely cause

zsh escapes `\!` inside a quoted heredoc, so `\!= null` reaches the file as `\\!= null` and `x\!`
as `x\\!`. The analyzer points at the line but the cause is invisible unless you look at the raw
bytes.

## Diagnosis

The analyzer error alone will not reveal this — inspect the raw bytes of the affected line, or run
`grep -rn '\\\!' lib/ test/` to find every corrupted occurrence across the tree.

## Fix

Do not write Dart containing `\!` through `python3 - <<EOF` or `cat <<EOF`. Use the Edit or Write
tool. If a heredoc already ran, `grep -rn '\\\!' lib/ test/` finds every occurrence.

## Prevention

Never write Dart code through a shell heredoc; use the Edit or Write tool instead — this avoids
the escaping corruption rather than grepping for it after the fact.

## Escalation

No owner or on-call for this single-developer project. If `non_bool_condition` or `expected_token`
appears at a line with `!`, run `grep -rn '\\\!' lib/ test/` to confirm heredoc corruption before
assuming a logic bug.
