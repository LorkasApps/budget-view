---
title: "The plausibility limit compares against printed total plus credits, not against the printed total alone"
date: 2026-08-24
tags:
  - adr
description: "The receipt plausibility check now compares parsed items against the printed total plus credits, since a deposit return (Pfandrückgabe) is already subtracted from the printed total and would otherwise throw out a legitimate item."
---

# 0131 — The plausibility limit compares against printed total plus credits, not against the printed total alone

**Status:** Accepted, 2026-08-24

## Context
A deposit return (`Pfandrückgabe`) is already subtracted from the printed total, so the line items sum higher than what was actually paid. Checked against the total alone, a legitimate item gets discarded once the return is large relative to the purchase. The bug was latent in the PDF parser too and never surfaced there, because the deposit was small on the receipt that had been checked — it was found by the test that compares both parsers on the same receipt.

## Decision
The plausibility limit compares against the printed total (`gedruckte Summe`) plus credits (`Gutschriften`), not against the printed total alone.

## Consequences
This closes a bug that existed silently in both parsers. The test that compares OCR and PDF parser output on the same receipt is what surfaced it — a case for keeping that cross-parser test in place.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
