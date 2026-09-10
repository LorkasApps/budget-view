---
title: No empty-key guard in the trend service
date: 2026-08-19
tags:
  - adr
description: The trend service has no guard against an empty description key, since LineItemRepository already validates the description as non-empty on every write and that branch is unreachable via any allowed write path.
---

# 0100 — No empty-key guard in the trend service

**Status:** Accepted, 2026-08-19

## Context

`LineItemRepository` validates the description as non-empty on every write; the branch is unreachable via any allowed write path (`der Zweig ist über keinen erlaubten Schreibpfad erreichbar`). Testing it would have needed a raw Isar write bypassing the repository boundary — more expensive than the protection is worth (`teurer als der Schutz wert ist`), the same line as the deleted `No*` fallbacks (0076).

## Decision

No empty-key guard is added in the trend service.

## Consequences

Adding and testing such a guard was rejected as more expensive than the protection is worth, following the same reasoning that removed the `No*` fallback classes.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
