---
title: "Superscript cents are composed; the row tolerance stays as tuned by 035"
date: 2026-08-24
tags:
  - adr
description: "Picnic prints price cents as a superscript token on a baseline 7 units away from the euro amount; rather than widen the shared row tolerance from 035, the price-column fragments are banded and read bottom-to-top, left-to-right, restricted to rows that are only a price fragment."
---

# 0132 — Superscript cents are composed; the row tolerance stays as tuned by 035

**Status:** Accepted, 2026-08-24

## Context
Picnic prints `3` and `79` on baselines 7 units apart — neither half is a money token on its own, so the row was dropped entirely and a photographed receipt delivered nothing. Widening the shared row tolerance would have regrouped every layout to solve a case that is solvable locally.

## Decision
Superscript cents are composed: the price-column fragments are banded, the bottom band is read left to right, and the last two digits are the cents. The row tolerance itself is left as ADR 0035 tuned it. The price column is taken only from the leftmost row that is *exclusively* a price fragment — without this guard, something like a `Kundennr 4711` would compose itself into an amount.

## Consequences
A photographed Picnic receipt that previously lost its price row now parses correctly, without touching the shared row-grouping tolerance used by every other layout. This decision was later replaced by ADR 0143 (2026-09-08), which removes superscript-cent composition after a real receipt dump contradicted the assumption behind it.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
