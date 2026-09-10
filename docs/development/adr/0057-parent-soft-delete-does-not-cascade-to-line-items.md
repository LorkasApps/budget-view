---
title: Parent soft-delete does not cascade to line items
date: 2026-08-13
tags:
  - adr
description: Soft-deleting a transaction does not cascade to its line items, since line items are only reachable through the transaction and a cascade would leave restoring a transaction incomplete.
---

# 0057 — Parent soft-delete does not cascade to line items

**Status:** Accepted, 2026-08-13

## Context

Line items are only reachable through their transaction (`Positionen sind nur über die Buchung erreichbar`), so unreachability alone is sufficient (`also genügt Unerreichbarkeit`); a cascade would leave restoring a transaction incomplete (`ein Cascade würde die Wiederherstellung einer Buchung unvollständig machen`).

## Decision

Parent soft-delete does not cascade to line items.

## Consequences

Restoring a soft-deleted transaction later restores its line items too, because they were never touched; a cascading soft-delete was rejected for making restoration incomplete.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
