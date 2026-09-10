---
title: "A month's line items load via an anyOf bulk query (findByTransactions), not N × findByTransaction"
date: 2026-08-18
tags:
  - adr
description: Line items for a month are fetched via a single anyOf bulk query rather than one findByTransaction call per transaction, keeping the report's per-run query count from growing with history.
---

# 0080 — A month's line items load via an anyOf bulk query (findByTransactions), not N × findByTransaction

**Status:** Accepted, 2026-08-18

## Context

The report recomputes across four collections on every change; N queries per run would grow with the app's history (`N Queries pro Lauf wachsen mit der Historie`). A custom Isar query written directly in `analytics/data` would have been faster to write, but would have broken the repository boundary that every other domain honors (`hätte aber die Repo-Grenze gebrochen, die jede andere Domain einhält`).

## Decision

Line items for a month load via an `anyOf` bulk query (`findByTransactions`), not N × `findByTransaction`.

## Consequences

The rejected alternative — a custom Isar query directly in `analytics/data` — would have been faster to write but would have broken the repository boundary every other domain keeps.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
