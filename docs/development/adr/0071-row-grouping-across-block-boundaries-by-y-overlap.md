---
title: Row grouping crosses block boundaries via y-overlap, price is the rightmost money token
date: 2026-08-17
tags:
  - adr
description: Receipt OCR row grouping crosses ML Kit's block boundaries using y-overlap, with the price taken as the rightmost money token, using coordinates instead of text patterns just like the ING column boundaries.
---

# 0071 — Row grouping crosses block boundaries via y-overlap, price is the rightmost money token

**Status:** Accepted, 2026-08-17

## Context

ML Kit often splits a receipt's item and price columns into separate blocks; block-by-block parsing would tear apart exactly the pairing that matters (`blockweises Parsen würde genau die Paarung zerreißen, um die es geht`).

## Decision

Row grouping crosses block boundaries, via y-overlap; the price is the rightmost money token (`Preis = rechtester Geldtoken`).

## Consequences

Coordinates are used instead of text patterns — the same line taken with the ING column boundaries (0036).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
