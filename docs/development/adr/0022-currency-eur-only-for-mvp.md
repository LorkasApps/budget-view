---
title: Currency is EUR only for the MVP, no field
date: 2026-08-10
tags:
  - adr
description: The MVP hard-codes EUR as the only currency, with no currency field, to reduce complexity; multi-currency is deferred to its own ticket.
---

# 0022 — Currency is EUR only for the MVP, no field

**Status:** Accepted, 2026-08-10

## Context

Supporting multiple currencies would add complexity that the MVP does not need.

## Decision

Currency = EUR only for the MVP (`für MVP`), with no currency field (`kein Feld`).

## Consequences

This reduces complexity (`Reduziert Komplexität`); multi-currency is deferred to its own, later ticket (`Multi-Currency später als eigenes Ticket`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
