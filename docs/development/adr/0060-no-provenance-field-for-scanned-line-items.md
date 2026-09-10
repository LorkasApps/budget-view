---
title: "No provenance field for \"line items from scans\", the planned counter is dropped"
date: 2026-08-17
tags:
  - adr
description: A purely informational counter for scan-derived line items does not justify a schema field; an honest version would need per-row provenance instead, deferred to ticket 018.
---

# 0060 — No provenance field for "line items from scans", the planned counter is dropped

**Status:** Accepted, 2026-08-17

## Context

A purely informational counter does not justify a schema field (`Ein rein informativer Zähler rechtfertigt kein Schema-Feld`). An honest version of it would only work per row (`LineItem.importedSourceUuid`) — that belongs after 018, where the rows are created, and carries real value there (badge, bulk-delete — `Badge, Sammel-Löschen`).

## Decision

No provenance field for "line items from scans" (`Positionen aus Scans`); the planned counter is dropped.

## Consequences

The planned counter is rejected as dishonest at the aggregate level; a per-row `LineItem.importedSourceUuid` field is deferred to ticket 018, where it provides real value (a badge, bulk-delete).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
