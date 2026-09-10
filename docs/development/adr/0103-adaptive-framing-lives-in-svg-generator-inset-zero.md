---
title: Adaptive framing lives in the SVG, generator inset = 0
date: 2026-08-20
tags:
  - adr
description: Adaptive-icon framing is baked into the SVG itself with the generator inset set to zero, since the default 16% inset would shrink an already safe-zone-framed mark to a visibly small size in the launcher grid.
---

# 0103 — Adaptive framing lives in the SVG, generator inset = 0

**Status:** Accepted, 2026-08-20

## Context

The default inset (16%) would shrink a mark already framed for the safe zone, making it visibly too small in the launcher grid (`würde eine bereits für Safe-Zone gerahmte Mark verkleinern, im Launcher-Grid sichtbar zu klein`).

## Decision

Adaptive framing lives in the SVG; the generator inset is set to 0.

## Consequences

Framing now sits at exactly one place (`Framing steht damit an genau einer Stelle`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
