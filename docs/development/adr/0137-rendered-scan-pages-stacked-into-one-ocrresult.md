---
title: "The rendered pages of a scan are stacked into one `OcrResult` and parsed once, not per page"
date: 2026-08-24
tags:
  - adr
description: "All rendered pages of a multi-page scan are stacked into a single OcrResult and parsed once, because the total, credits, and plausibility limit are only meaningful document-wide, and a naive per-page mix could pair a description on page two with a price from page one."
---

# 0137 — The rendered pages of a scan are stacked into one `OcrResult` and parsed once, not per page

**Status:** Accepted, 2026-08-24

## Context
Every page starts at y=0; mixed naively, a description from page two could be paired with a price from page one. More importantly, the total, credits, and plausibility limit are only meaningful document-wide: the printed total sits on the last page and must bound the line items of the first.

## Decision
The rendered pages of a scan are stacked into **one** `OcrResult` and parsed once, not per page. Each page after the first is shifted below the previous one, at a gap no row grouping can bridge.

## Consequences
Total, credits, and plausibility checks work correctly across page boundaries, at the cost of the stacking step and its deliberately unbridgeable gap between pages.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
