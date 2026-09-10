---
title: "In the OCR path, the price anchors the row, and the reach upward is the median gap between consecutive prices — no more tolerance from text height"
date: 2026-09-08
tags:
  - adr
description: "Row grouping in the OCR path now anchors on the price and reaches upward by the median distance between consecutive real prices, replacing a line-height-derived tolerance, after a real Picnic photo dump showed no price row ever shares a band with its item name."
---

# 0142 — In the OCR path, the price anchors the row, and the reach upward is the median gap between consecutive prices — no more tolerance from text height

**Status:** Accepted, 2026-09-08

## Context
The dump of a real Picnic photo shows: no price row ever shares a band with its item name. A product image pushes the name 14–30 px above the price, the text itself is 7–17 px tall, so any tolerance scaled from line height (before ADR 0055: `(line height + max line height) / 4` ≈ 8 px) sits fundamentally too shallow. Scaling would only have moved the number, not the reference quantity: the line spacing is the measure that actually separates one item from the next, and it is readable per document from the prices themselves (87 px in the dump, range 85–88). Rows that reach no price stay as diagnosis instead of joining a row — this is how the page header stays excluded without the parser knowing it by vocabulary.

## Decision
In the OCR path, the **price** anchors the row, and the reach upward is the median gap between consecutive prices — no more tolerance derived from text height.

## Consequences
Row grouping now derives its tolerance from the document's own price spacing instead of a line-height heuristic that a real photo dump proved wrong.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
