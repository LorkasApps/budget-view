---
title: For Trade Republic, ISIN is the counterparty, not the instrument name
date: 2026-08-24
tags:
  - adr
description: Trade Republic bookings use the ISIN as counterparty because the statement prints no instrument name, and a constant counterparty would falsely collide same-day, same-amount positions in the dedupe hash.
---

# 0124 — For Trade Republic, ISIN is the counterparty, not the instrument name

**Status:** Accepted, 2026-08-24

## Context

The statement prints no instrument name, only `Cash Dividend for ISIN IE00077FRP95`. The dedupe hash covers amount, date and normalized counterparty, so a constant would collapse two positions paying the same amount on the same day into a false duplicate.

## Decision

For Trade Republic, ISIN is the counterparty, not the instrument name.

## Consequences

This also gives the tagging loop one rule per position, rather than a shared, ambiguous rule.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
