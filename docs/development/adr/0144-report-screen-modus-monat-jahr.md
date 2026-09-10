---
title: "The result is a mode of the report screen (`Monat` / `Jahr`), not a second surface; years are stepped with two arrows and a label"
date: 2026-09-08
tags:
  - adr
description: "Yearly results appear as a Monat/Jahr mode of the existing report screen rather than a separate surface, since computeSeries already returns twelve points in one run and a dedicated screen would have duplicated the filter bar and competed with forecast and price trends behind Mehr."
---

# 0144 — The result is a mode of the report screen (`Monat` / `Jahr`), not a second surface; years are stepped with two arrows and a label

**Status:** Accepted, 2026-09-08

## Context
User choice at ticket 052. `computeSeries` (ADR 0021) already delivers the twelve points in one run, and a dedicated surface would have competed with forecast and price trends behind `Mehr` and duplicated the filter bar. In year mode, the monthly breakdown replaces the category table — "how did the months develop" is the question a year answers, and a category table spanning twelve months is the wrong tool for that. The direction filter disappears there too, since no table remains for it to act on. No `DatePicker` one level up: the day-grid compromise from 2026-08-20 was already a crutch at the month level, and a calendar year is two arrows away.

## Decision
The result is a **mode** of the report screen (`Monat` / `Jahr`), not a second surface; years are stepped with two arrows and a label.

## Consequences
The mode does not touch `MonthlyReportFilter`, so the month view survives an excursion into the year view unchanged.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
