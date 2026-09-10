---
title: "The two item providers are autoDispose, the report and forecast providers are not"
date: 2026-08-19
tags:
  - adr
description: The two item-related providers use autoDispose because their family key is free-form user text whose key count grows with typing, unlike the bounded field combinations behind the report filters.
---

# 0098 — The two item providers are autoDispose, the report and forecast providers are not

**Status:** Accepted, 2026-08-19

## Context

Their family key is user text — a search string or an item description — so the number of keys grows with typing (`die Zahl der Keys wächst also mit dem Tippen`). The report filters' key space is bounded by the field combination instead (`Bei den Report-Filtern ist sie durch die Feldkombination begrenzt`).

## Decision

The two item providers are `autoDispose`; the report and forecast providers are not.

## Consequences

Unbounded, user-text-keyed providers get `autoDispose` to avoid unbounded growth; bounded, field-combination-keyed providers do not need it.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
