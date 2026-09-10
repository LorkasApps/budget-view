---
title: "A bottom-nav tab is earned by usage frequency; rare surfaces move behind Mehr / MenuScreen"
date: 2026-08-18
tags:
  - adr
description: Bottom-navigation tabs are reserved for frequently used surfaces, with rarer ones (including the forecast) moved behind a Mehr menu screen, since Material 3 allows only 3-5 destinations.
---

# 0091 — A bottom-nav tab is earned by usage frequency; rare surfaces move behind Mehr / MenuScreen

**Status:** Accepted, 2026-08-18

## Context

Material 3 allows 3–5 destinations, and tickets 022/024/025 would have driven the bar to six (`hätten die Leiste auf sechs getrieben`). The expensive part is not the menu itself, but moving the shell, tests and docs twice — which is why this was built before ticket 022 (`der teure Teil ist nicht das Menü, sondern das zweimalige Umziehen von Shell, Tests und Docs — deshalb vor 022 gebaut`).

## Decision

A bottom-nav tab is earned by usage frequency; rare surfaces sit behind `Mehr` → `MenuScreen`. The forecast moved there too (`Prognose ist mit umgezogen`).

## Consequences

The forecast loses nothing by this move: its natural path remains the long-press from the report row (0086) (`ihr natürlicher Weg ist der Long-Press aus der Report-Zeile`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
