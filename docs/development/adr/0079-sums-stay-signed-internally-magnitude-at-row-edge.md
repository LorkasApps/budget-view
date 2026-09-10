---
title: "Sums stay signed internally, magnitudes only appear at the row edge (abs())"
date: 2026-08-18
tags:
  - adr
description: Report totals stay signed internally so a subtree can net against itself, with abs() applied only at the row edge for display, since positive-only rollups would double-count amount and counter-amount.
---

# 0079 — Sums stay signed internally, magnitudes only appear at the row edge (abs())

**Status:** Accepted, 2026-08-18

## Context

A subtree must be able to net against itself, otherwise the rollup adds an amount and its counter-amount into a doubled sum (`sonst addiert der Rollup Betrag und Gegenbetrag zur doppelten Summe`). The display still wants positive numbers (`Die Anzeige will trotzdem positive Zahlen`).

## Decision

Sums stay signed internally; magnitudes appear only at the row edge, via `abs()`.

## Consequences

A subtree can net an amount against its counter-amount without the rollup doubling the total, while the UI still shows plain positive numbers.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
