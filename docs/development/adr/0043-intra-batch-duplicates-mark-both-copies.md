---
title: Intra-batch duplicates mark both copies
date: 2026-08-12
tags:
  - adr
description: When two rows in the same import batch duplicate each other, both copies are marked, since the second row is not automatically the wrong one.
---

# 0043 — Intra-batch duplicates mark both copies

**Status:** Accepted, 2026-08-12

## Context

When a duplicate is found within the same import batch, the second occurrence is not automatically the incorrect one (`Die zweite ist nicht automatisch die falsche`).

## Decision

Intra-batch duplicates mark **both** copies (`markieren **beide** Kopien`).

## Consequences

The user decides which copy stays (`der User entscheidet, welche bleibt`), rather than the system guessing which one is wrong.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
