---
title: "Direction filter (expenses/income) decides at the transaction, not the line item"
date: 2026-08-18
tags:
  - adr
description: The report's income/expense direction filter looks at the transaction, not the individual line item, since a Restposten legitimately shows against its siblings and per-line filtering would double-count.
---

# 0078 — Direction filter (expenses/income) decides at the transaction, not the line item

**Status:** Accepted, 2026-08-18

## Context

An overshooting `Restposten` legitimately shows against its siblings (see the 2026-08-13 decision, 0052). Filtered per line item, the +5 `Restposten` of a −50 transaction would have wandered into the income report, and the expense side would have reported 55 instead of 50 (`hätte der +5-Restposten einer −50-Buchung in den Einnahmen-Report gewandert, und die Ausgabenseite hätte 55 statt 50 gemeldet`).

## Decision

The direction filter (expenses/income) decides at the **transaction**, not the individual line item.

## Consequences

Per-line-item filtering is rejected because it would have moved a `Restposten` into the wrong direction's report and misreported the other side's total.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
