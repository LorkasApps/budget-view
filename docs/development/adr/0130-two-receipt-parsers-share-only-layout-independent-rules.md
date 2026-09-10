---
title: The two receipt parsers share only layout-independent rules, they do not converge into one implementation
date: 2026-08-24
tags:
  - adr
description: "The OCR and PDF receipt parsers share only receipt_row_rules.dart; every concrete defect from ticket 043 was fixable locally, so converging both paths would have reworked two working pipelines for no benefit."
---

# 0130 — The two receipt parsers share only layout-independent rules, they do not converge into one implementation

**Status:** Accepted, 2026-08-24

## Context

Every concrete defect from ticket 043 sat in the shared half, or at a spot the OCR parser could repair locally — a convergence would have reworked two working paths to fix bugs that were already fixable without a rework. Its benefit only begins at a third source, and the rules that truly need geometry stay source-specific anyway: a thermal print and a PDF text layer deliver different rectangles.

## Decision

The two receipt (`Bon`) parsers share only the layout-independent rules (`receipt_row_rules.dart`); they do not converge onto one implementation.

## Consequences

Skip vocabulary stays per-parser too (`Skip-Vokabular bleibt deshalb auch pro Parser`), since the rules that need real geometry cannot be shared between a thermal print and a PDF text layer.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
