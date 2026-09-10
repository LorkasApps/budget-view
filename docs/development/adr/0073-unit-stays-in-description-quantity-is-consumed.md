---
title: Unit of measure stays in the description text, quantity is consumed from it
date: 2026-08-17
tags:
  - adr
description: The unit of measure stays embedded in the description text rather than a dedicated field, since LineItem has no unit field and stripping the quantity token would otherwise lose it.
---

# 0073 — Unit of measure stays in the description text, quantity is consumed from it

**Status:** Accepted, 2026-08-17

## Context

`LineItem` has no unit field (see 015), so the unit lives in the description. "1,5 kg Äpfel" would otherwise lose the "kg" (`würde sonst das kg verlieren`), while "2x Milch" already carries the 2 in `quantity`.

## Decision

The unit of measure stays in the description text; the quantity token is consumed (`Stückzahl wird konsumiert`).

## Consequences

A description like "1,5 kg Äpfel" keeps its unit; a description like "2x Milch" has its count captured separately in `quantity` while the description loses only the count, not a unit.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
