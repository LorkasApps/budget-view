---
title: "OcrResult carries layout (blocks, lines, Rect), not just flat strings"
date: 2026-08-17
tags:
  - adr
description: OcrResult keeps ML Kit's block, line and Rect layout information rather than flattening to plain strings, since receipt heuristics rely on x-positions the same way ING's column boundaries do.
---

# 0065 — OcrResult carries layout (blocks, lines, Rect), not just flat strings

**Status:** Accepted, 2026-08-17

## Context

ML Kit provides coordinates for free, and receipt (`Bon`) heuristics live on x-positions — prices right-aligned, discounts indented (`Preise rechtsbündig, Rabatte eingerückt`) — the same lesson as the ING column boundaries (0036). Breaking the contract written in 016 was cheap because no consumer existed yet; later, the discarded information would be expensive to recover (`später wäre die verworfene Information teuer zurückzuholen`).

## Decision

`OcrResult` carries layout (blocks, lines, `Rect`), not just flat strings.

## Consequences

The 016 contract for `OcrResult` was broken while it was still cheap to break, because no consumer existed yet; keeping it flat would have made recovering the layout information expensive later.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
