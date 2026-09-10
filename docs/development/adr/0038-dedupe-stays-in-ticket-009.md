---
title: Dedupe stays entirely in ticket 009, ticket 008 only imports
date: 2026-08-11
tags:
  - adr
description: To break a cyclical dependency between tickets 008 and 009, ticket 008 only imports data and ticket 009 owns deduplication and warnings entirely.
---

# 0038 — Dedupe stays entirely in ticket 009, ticket 008 only imports

**Status:** Accepted, 2026-08-11

## Context

Ticket 008's acceptance criteria required artifacts from ticket 009, while ticket 009 was blocked on ticket 008 — a cycle (`008-ACs verlangten 009-Artefakte, während 009 auf 008 blockte`).

## Decision

Dedupe stays entirely in ticket 009; ticket 008 only imports (`Dedupe bleibt komplett in Ticket 009, 008 importiert nur`).

## Consequences

The cycle is resolved by the cut "008 imports, 009 warns" (`Zyklus aufgelöst durch Schnitt "008 imports, 009 warns"`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
