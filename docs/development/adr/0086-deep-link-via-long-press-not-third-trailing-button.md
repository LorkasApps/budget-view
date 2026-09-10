---
title: Deep-link via long-press on the report row, not a third trailing button
date: 2026-08-18
tags:
  - adr
description: The forecast deep-link is a long-press on the report row rather than a third trailing button, since amount plus chevron plus button in one ListTile.trailing already overflowed once before.
---

# 0086 — Deep-link via long-press on the report row, not a third trailing button

**Status:** Accepted, 2026-08-18

## Context

Amount + chevron + button in one `ListTile.trailing` is exactly the row that has already overflowed once before (`ist genau die Zeile, die schon einmal übergelaufen ist`, see `errors.md`). Long-press is an established interaction in this app: `CategoryTreeScreen` archives this way.

## Decision

The forecast deep-link is triggered by long-press on the report row, not a third trailing button.

## Consequences

A third trailing button is rejected because it repeats a row layout that already overflowed once; long-press is reused as an established pattern from `CategoryTreeScreen`.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
