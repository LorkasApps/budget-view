---
title: Category resolver lives in Drilldown, not the Category path from ticket 012
date: 2026-08-13
tags:
  - adr
description: The category resolver lives in the Drilldown domain rather than the Category path ticket 012 named, because its functions take a LineItem and Category only depends on infra plus a narrow Transaction edge.
---

# 0049 — Category resolver lives in Drilldown, not the Category path from ticket 012

**Status:** Accepted, 2026-08-13

## Context

The resolver's functions take a `LineItem`; `Category` only depends on infra plus the narrow Transaction edge (`Category hängt nur an Infra plus der schmalen Transaction-Kante`). The ticket's suggested path would have newly wired `Category → Drilldown`, for a rule whose subject is the line item (`für eine Regel, deren Gegenstand die Position ist`). Analytics (020, 022) depends on both domains anyway.

## Decision

The category resolver lives in `Drilldown`, not in the `Category` path named by ticket 012.

## Consequences

The `Category → Drilldown` dependency edge the ticket's suggested path would have introduced is avoided, since Analytics already depends on both domains regardless.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
