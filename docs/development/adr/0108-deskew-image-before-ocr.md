---
title: Deskew the image before OCR, instead of compensating angle only in row grouping
date: 2026-08-21
tags:
  - adr
description: Receipt photos are deskewed before OCR rather than compensating for angle only during row grouping, because deskewing also improves recognition itself, not just the pairing of tokens.
---

# 0108 — Deskew the image before OCR, instead of compensating angle only in row grouping

**Status:** Accepted, 2026-08-21

## Context

This was a user choice at 035: deskewing improves recognition itself, not just the pairing (`das Entzerren verbessert die Erkennung selbst mit, nicht nur die Zuordnung`). The cheaper alternative — estimating the angle from bounding boxes and rotating coordinates back — would only have saved the pairing (`haette nur die Paarung gerettet`).

## Decision

The image is deskewed before OCR, instead of compensating for the angle only in row grouping.

## Consequences

Cost accepted deliberately: this runs before every scan, even straight photos (`laeuft vor jedem Scan, auch bei geraden Fotos`). The angle comes from a projection profile over dark pixels — the bins are computed from coordinates, the bitmap is not rotated per candidate angle (`das Bitmap wird nicht pro Kandidatenwinkel gedreht`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
