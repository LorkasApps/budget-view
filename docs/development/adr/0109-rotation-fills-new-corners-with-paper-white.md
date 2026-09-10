---
title: Rotation fills new corners with paper white
date: 2026-08-21
tags:
  - adr
description: Deskew rotation fills newly exposed corners with paper white instead of img.copyRotate's default black background, since black corners would distort recognition and any later angle estimate.
---

# 0109 — Rotation fills new corners with paper white

**Status:** Accepted, 2026-08-21

## Context

`img.copyRotate` uses the image's background color, which defaults to black. On a photo of white paper this would be a large dark area, disturbing recognition and skewing any later angle estimate, since the method counts dark pixels (`sie stoert die Erkennung und wuerde jede spaetere Winkelschaetzung verfaelschen, weil das Verfahren dunkle Pixel zaehlt`). Noticed while writing the test, not while writing the code (`Beim Schreiben des Tests aufgefallen, nicht beim Schreiben des Codes`).

## Decision

Rotation fills newly exposed corners with paper white, instead of `img.copyRotate`'s default black.

## Consequences

This avoids the dark-corner artifact that would have disturbed both recognition and any later dark-pixel-based angle estimate.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
