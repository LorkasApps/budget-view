---
title: Newly appended @enumerated value reads back as the first value
date: 2026-09-10
tags:
  - troubleshooting
description: A newly appended @enumerated value reads back as the first enum value because Isar's generated .g.dart index table was not regenerated after the enum changed.
---

# Newly appended @enumerated value reads back as the first value

## Symptom

A newly appended `@enumerated` value reads back as the **first** value of the enum.

## Impact

Silently corrupts data on read: the write appears to succeed, but the stored intent is lost and
replaced with the wrong enum value, with no error raised.

## Likely cause

Isar stores the value by index, and the generated `.g.dart` maps indexes through a table built at
generation time. An index the table does not know falls back to the first entry, so the write
looks fine and the read is silently wrong.

## Diagnosis

A write-only test will not catch this — it must be a round-trip test (write, then read back) to
surface the silent fallback to the first enum value.

## Fix

Run `make gen` after adding an enum value. Appending needs no `kDbSchemaVersion` bump — the stored
shape does not change — but it does need regenerated code. A round-trip test catches it; a
write-only test does not.

## Prevention

Run `make gen` immediately after adding any `@enumerated` value, before writing or testing code
that uses it — this prevents the stale index table from ever being reached at read time.

## Escalation

No owner or on-call for this single-developer project. Reproduce with a round-trip test
(`make test-name NAME="..."`) that writes the new enum value and reads it back; if it comes back
as the first value, run `make gen` and re-test.
