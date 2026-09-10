---
title: Item grouping uses normalizeForMatching, no fuzzy merge of OCR variants
date: 2026-08-19
tags:
  - adr
description: "Price-trend item grouping relies on normalizeForMatching rather than fuzzy-merging OCR variants, since variety differences (e.g. h-milch 1,5% vs 3,5%) are real price differences that no heuristic can safely tell apart from a scan typo."
---

# 0096 — Item grouping uses normalizeForMatching, no fuzzy merge of OCR variants

**Status:** Accepted, 2026-08-19

## Context

Varieties carry real price differences (`h-milch 1,5 %` ≠ `h-milch 3,5 %`), and no heuristic separates that from a scan typo (`keine Heuristik trennt das von einem Scan-Tippfehler`).

## Decision

Item grouping uses `normalizeForMatching`, with no fuzzy merge of OCR variants.

## Consequences

This is the same function used for dedupe and tagging, so "the same item" means the same thing in all three cases (`damit „derselbe Artikel" in allen drei Fällen dasselbe heißt`). A merge tool will only be built once real receipt data shows the pain (`Ein Merge-Werkzeug wird erst gebaut, wenn echte Bondaten den Schmerz zeigen`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
