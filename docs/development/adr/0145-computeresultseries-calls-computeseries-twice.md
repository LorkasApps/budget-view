---
title: "`computeResultSeries` calls `computeSeries` twice (once per direction), instead of sharing the load in the service for both directions"
date: 2026-09-08
tags:
  - adr
description: "computeResultSeries calls computeSeries twice, once per direction, rather than sharing a single load for both, so the three result numbers stay identical to totalCents shown in the table below and no second aggregation can drift from resolver, rollup, and transfer exclusion."
---

# 0145 — `computeResultSeries` calls `computeSeries` twice (once per direction), instead of sharing the load in the service for both directions

**Status:** Accepted, 2026-09-08

## Context
User choice at ticket 052, against the refactor variant. The three numbers are exactly the `totalCents` the table below also shows — a result must not contradict its own rows, and this way **no** second aggregation exists that could drift from the category resolver, rollup, and transfer exclusion. A shared load would have touched the core that Report, Drilldown, and Forecast all hang from, including the `windowMonths == null` path that derives the series start from the earliest *directed* transaction.

## Decision
`computeResultSeries` calls `computeSeries` **twice** (once per direction), instead of sharing the load in the service for both directions.

## Consequences
Deliberate price: an extra pass over transactions, line items, and the category tree per recalculation — tolerable on local Isar with a single user. Since `findByAccount` has no date boundary anyway, a per-month query (ADR 0059) would be the more effective lever if this ever needs optimizing.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
