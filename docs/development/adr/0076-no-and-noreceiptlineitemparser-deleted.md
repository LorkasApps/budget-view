---
title: "NoOcrService and NoReceiptLineItemParser are deleted, not kept as a fallback"
date: 2026-08-17
tags:
  - adr
description: The no-op OCR service and line-item parser fakes were deleted rather than kept as a claimed safety net, because after 017/018 nothing, not even a test, referenced them anymore.
---

# 0076 — NoOcrService and NoReceiptLineItemParser are deleted, not kept as a fallback

**Status:** Accepted, 2026-08-17

## Context

After 017/018, nobody references them anymore, not even a test — the test suites' fakes are their own classes (`die Fakes der Suites sind eigene Klassen`).

## Decision

`NoOcrService` and `NoReceiptLineItemParser` are deleted, instead of being kept as a claimed fallback.

## Consequences

This removes dead code that would have been read as a safety net (`Toter Code, der als Sicherheitsnetz gelesen worden wäre`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
