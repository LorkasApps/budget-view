---
title: "A categoryUuid pointing to no existing category counts as \"Ohne Kategorie\""
date: 2026-08-18
tags:
  - adr
description: A dangling categoryUuid is treated as uncategorized (Ohne Kategorie) rather than dropped, so the amount cannot silently disappear from the report.
---

# 0081 — A categoryUuid pointing to no existing category counts as "Ohne Kategorie"

**Status:** Accepted, 2026-08-18

## Context

Otherwise the amount would silently disappear from the report (`Sonst verschwindet der Betrag lautlos aus dem Report`) — the same class of error that the dedicated uncategorized block is meant to make visible.

## Decision

A `categoryUuid` pointing to no existing category counts as "Ohne Kategorie" (uncategorized).

## Consequences

This is the same error class the uncategorized block already exists to surface, and it now also catches a dangling reference rather than letting it vanish silently.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
