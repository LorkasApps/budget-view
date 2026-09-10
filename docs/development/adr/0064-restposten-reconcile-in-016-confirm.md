---
title: "Restposten reconcile already runs at 016's confirm step, not first in 018"
date: 2026-08-17
tags:
  - adr
description: The Restposten reconcile call is already wired into ticket 016's confirm step, since 016 already writes line items and a write path without reconcile would break the sum invariant from 019.
---

# 0064 — Restposten reconcile already runs at 016's confirm step, not first in 018

**Status:** Accepted, 2026-08-17

## Context

016 already writes line items, and a write path without reconcile would have broken the sum invariant from 019 (`ein Schreibpfad ohne Reconcile hätte die Summen-Invariante aus 019 gebrochen`).

## Decision

`Restposten` reconcile runs already in 016's confirm step, not first added in 018.

## Consequences

018 inherits the call instead of having to retrofit it (`018 erbt den Aufruf statt ihn nachzurüsten`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
