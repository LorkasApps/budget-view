---
title: Category suggestion fires on leaving the payee field, not per keystroke
date: 2026-08-19
tags:
  - adr
description: The category suggestion lookup runs when the payee field loses focus rather than on every keystroke, since every lookup is an Isar query and a half-typed payee matches no rule anyway.
---

# 0093 — Category suggestion fires on leaving the payee field, not per keystroke

**Status:** Accepted, 2026-08-19

## Context

Every lookup is an Isar query, and a half-typed payee matches no rule anyway (`ein halb getippter Empfänger matcht ohnehin keine Regel`).

## Decision

The suggestion lookup runs on leaving the payee field (`beim Verlassen des Empfänger-Felds`), not per keystroke.

## Consequences

This follows the same line as the debounce on the item search introduced in ticket 022 (`Gleiche Linie wie der Debounce der Artikel-Suche aus 022`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
