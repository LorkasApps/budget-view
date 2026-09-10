---
title: "The merchant segment is cut at `Refr`, without proof that the reference changes per transaction"
date: 2026-09-10
tags:
  - adr
description: "The merchant segment for Nexi terminal references is cut at Refr even though a single observed Nexi row cannot prove whether the trailing reference number is per-transaction or fixed per terminal, since cutting is correct either way and waiting for a second statement is not."
---

# 0149 — The merchant segment is cut at `Refr`, without proof that the reference changes per transaction

**Status:** Accepted, 2026-09-10

## Context
Nexi prints `BAECKEREI SCHMIDT E K INHA 301 Refr GIR 79998979//…`. Only **one** Nexi row exists so far, so there is no way to tell whether `79998979` is fixed per terminal or changes per transaction. If it changes, the raw segment would be a key per purchase and produce exactly the rule explosion the name list (ADR 0148) was chosen to avoid.

## Decision
The merchant segment is cut at `Refr`, without proof that the reference changes per transaction. The terminal number `301` stays in: it plausibly belongs to the store, and removing it would be a second assumption stacked on the first.

## Consequences
Cutting is correct in either case (per-transaction or per-terminal reference); waiting for a second statement to confirm is not. The resulting key `BAECKEREI SCHMIDT E K INHA 301` keeps the legal form and the terminal number, which is accepted: a key has to be stable, not presentable.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
