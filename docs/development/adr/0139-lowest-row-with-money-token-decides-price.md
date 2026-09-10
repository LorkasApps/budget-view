---
title: "In the OCR path, the lowest row with a money token decides the price; within the row, the rightmost token wins"
date: 2026-08-24
tags:
  - adr
description: "The OCR parser picks the price from the lowest row carrying a money token, and the rightmost token within that row, because a promo row prints the crossed-out original price above the real one, both right-aligned, and choosing by x alone was random since Dart's List.sort is not stable."
---

# 0139 — In the OCR path, the lowest row with a money token decides the price; within the row, the rightmost token wins

**Status:** Accepted, 2026-08-24

## Context
A promo row prints the crossed-out original price above the real one, both right-aligned — chosen by x alone, the winner was random, because `List.sort` in Dart is not stable. This is the same rule as the PDF parser's lowest price band.

## Decision
In the OCR path, the **lowest** row carrying a money token decides the price; within that row, the rightmost token wins.

## Consequences
A row consisting only of a price no longer contributes description text and stays visible alone in `rawOcrText`.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
