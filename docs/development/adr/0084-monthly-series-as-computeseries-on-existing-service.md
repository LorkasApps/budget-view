---
title: "Monthly series is computeSeries() on the existing report service, not N × compute() and not an extracted unit helper"
date: 2026-08-18
tags:
  - adr
description: The monthly series is computed by a new computeSeries() method on the existing report service class, loading transactions, line items and the category tree once per series instead of once per month.
---

# 0084 — Monthly series is computeSeries() on the existing report service, not N × compute() and not an extracted unit helper

**Status:** Accepted, 2026-08-18

## Context

This was a user choice at ticket 021. Resolver, rollup, direction and uncategorized handling stay in the class that already owns them (`Resolver, Rollup, Richtung und Uncategorized bleiben in der Klasse, die sie schon besitzt`); transactions, line items and the category tree are loaded once per series instead of once per month.

## Decision

The monthly series is `computeSeries()` on the existing report service, not N × `compute()` and not an extracted unit helper.

## Consequences

`compute()` now delegates with `windowMonths: 1` — one code path instead of two (`ein Pfad statt zwei`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
