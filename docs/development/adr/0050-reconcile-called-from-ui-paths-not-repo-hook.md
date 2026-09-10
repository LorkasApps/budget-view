---
title: "reconcile() is called from UI paths, not a hook in TransactionRepository.save"
date: 2026-08-13
tags:
  - adr
description: reconcile() is invoked from four UI call sites rather than a hook in TransactionRepository.save, to avoid reversing the Transaction to Drilldown dependency for a rule that belongs to line items.
---

# 0050 — reconcile() is called from UI paths, not a hook in TransactionRepository.save

**Status:** Accepted, 2026-08-13

## Context

A hook in `TransactionRepository.save` would have turned the `Transaction → Drilldown` dependency around, for a rule that belongs to line items (`für eine Regel, die den Positionen gehört`).

## Decision

`reconcile()` is called from the UI paths, not via a hook in `TransactionRepository.save`.

## Consequences

There are four call sites (sheet save, section delete, section reorder, transaction form) instead of one central place — risk: a future write path touching `amountCents` forgets the call (`ein künftiger Schreibpfad auf \`amountCents\` vergisst den Aufruf`). PDF import is uncritical, and fresh bookings have no line items yet (`PDF-Import ist unkritisch, frische Buchungen haben keine Positionen`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
