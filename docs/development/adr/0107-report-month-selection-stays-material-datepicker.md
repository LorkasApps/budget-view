---
title: Month selection in the report stays the Material DatePicker with a day grid, no dedicated month dialog
date: 2026-08-20
tags:
  - adr
description: The report's month picker remains the standard Material day-grid DatePicker rather than a custom month dialog, since DatePickerMode only offers day and year, and the misleading day-level precision was knowingly accepted.
---

# 0107 — Month selection in the report stays the Material DatePicker with a day grid, no dedicated month dialog

**Status:** Accepted, 2026-08-20

## Context

`DatePickerMode` only knows `day` and `year` — a month-precise picker would have to be built as its own widget, including keyboard and screen-reader behavior. The day is inconsequential (`Der Tag ist folgenlos`): 05.06 and 20.06 both resolve to June. Found during the 028 pass (`Befund aus dem 028-Durchgang`).

## Decision

Month selection in the report stays the Material `DatePicker` with a day grid, no dedicated month dialog.

## Consequences

The misleading precision (a day-level picker for a month-level choice) was knowingly accepted (`die irreführende Genauigkeit wurde bewusst in Kauf genommen`) rather than building a custom month widget with its own accessibility behavior.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
