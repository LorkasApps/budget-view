---
title: "PNG rasterization is in-repo via tool/svg_to_png.py + make icon-png, instead of manual user export"
date: 2026-08-20
tags:
  - adr
description: PNG icon rasterization runs in-repo via a script and a make target rather than manual export, keeping SVGs as the single source and the raster from ever going stale.
---

# 0101 — PNG rasterization is in-repo via tool/svg_to_png.py + make icon-png, instead of manual user export

**Status:** Accepted, 2026-08-20

## Context

SVGs remain the single source (`SVGs bleiben einzelne Quelle`); a design tweak should be a single `make` call instead of three manual exports.

## Decision

PNG rasterization happens in-repo via `tool/svg_to_png.py` plus `make icon-png`, instead of manual user export.

## Consequences

`make icons` and `make splash` depend on `icon-png`, so the raster cannot go stale (`der Raster kann nicht veralten`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
