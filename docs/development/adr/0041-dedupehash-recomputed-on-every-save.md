---
title: dedupeHash is recomputed on every save, not only when empty
date: 2026-08-12
tags:
  - adr
description: dedupeHash is recomputed on every save rather than only when empty, so it never describes a stale version of the booking after an amount, date or payee correction.
---

# 0041 — dedupeHash is recomputed on every save, not only when empty

**Status:** Accepted, 2026-08-12

## Context

Otherwise, after an amount, date, or payee correction, the hash would still describe the old booking, and duplicate checking would compare against something that no longer exists (`Sonst beschreibt der Hash nach einer Betrags-, Datums- oder Empfänger-Korrektur die alte Buchung, und die Duplikatprüfung vergleicht gegen etwas, das nicht mehr existiert`).

## Decision

`dedupeHash` is recomputed on *every* save, not only when it is empty (`bei *jedem* Save neu berechnet, nicht nur wenn leer`).

## Consequences

The hash always reflects the current state of the booking, keeping duplicate detection accurate after edits.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
