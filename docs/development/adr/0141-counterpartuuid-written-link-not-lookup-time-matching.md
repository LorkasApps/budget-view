---
title: "The pair is recognized via a written link `Transaction.counterpartUuid`, not read-time matching on amount, date, and the two accounts"
date: 2026-09-07
tags:
  - adr
description: "Transfer pairs are identified through an explicit Transaction.counterpartUuid link set at creation time rather than inferred by matching amount, date, and accounts at read time, since inferred matching invents connections and a same-day equal amount is not necessarily a transfer."
---

# 0141 — The pair is recognized via a written link `Transaction.counterpartUuid`, not read-time matching on amount, date, and the two accounts

**Status:** Accepted, 2026-09-07

## Context
This continues the 2026-08-21 decision: matching invents connections — two coincidentally equal amounts on the same day are not a transfer. A link the user creates at entry time is a fact instead of a guess. The field is additive, so it does **not** bump `kDbSchemaVersion` — the same line as `Transaction.kind` in ADR 0032.

## Decision
The pair is recognized via a written link `Transaction.counterpartUuid`, not read-time matching on amount, date, and the two accounts.

## Consequences
The counterpart leg is **moved** (uuid stable, an `update` in the change queue) when the target account changes, rather than deleted and re-created, so user edits on that row survive.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
