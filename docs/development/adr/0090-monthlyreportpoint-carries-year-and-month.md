---
title: "MonthlyReportPoint carries year + month alongside the report, instead of on MonthlyCategoryReport"
date: 2026-08-18
tags:
  - adr
description: Year and month live on MonthlyReportPoint rather than on MonthlyCategoryReport, because MonthlyCategoryReport.empty must stay const, which month fields would prevent.
---

# 0090 — MonthlyReportPoint carries year + month alongside the report, instead of on MonthlyCategoryReport

**Status:** Accepted, 2026-08-18

## Context

Without this, a report would not know which month it describes (`Ein Report weiß sonst nicht, welchen Monat er beschreibt`), but `MonthlyCategoryReport.empty` must stay `const` — adding month fields there would prevent that (`mit Monatsfeldern ginge das nicht`).

## Decision

`MonthlyReportPoint` carries year plus month alongside the report, instead of placing them on `MonthlyCategoryReport`.

## Consequences

`MonthlyCategoryReport.empty` keeps its `const` constructor; the rejected alternative would have broken that.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
