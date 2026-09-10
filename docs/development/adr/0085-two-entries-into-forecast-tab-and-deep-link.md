---
title: Two entry points into the forecast, shell tab and deep-link from the report row
date: 2026-08-18
tags:
  - adr
description: The forecast is reachable both from a dedicated shell tab and via a deep-link from a report row that carries over category, account, direction and month, so report and forecast cannot disagree about the same category's numbers.
---

# 0085 — Two entry points into the forecast, shell tab and deep-link from the report row

**Status:** Accepted, 2026-08-18

## Context

This was a user choice at ticket 021. The tab makes the forecast directly reachable; the deep-link carries over category, account, direction and month (`übernimmt Kategorie, Konto, Richtung und Monat`).

## Decision

There are two entry points into the forecast: the shell tab **and** a deep-link from the report row.

## Consequences

The report and the forecast cannot show different numbers for the same category, since the deep-link carries the exact filter context over.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
