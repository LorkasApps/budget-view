---
title: The user marks transfers manually; no automatic pairing, no counterparty rule
date: 2026-08-21
tags:
  - adr
description: Transfers are marked by the user rather than paired automatically, because pairing invents relationships and a false-positive counterparty rule would hide real expenses from the report without anyone noticing.
---

# 0113 — The user marks transfers manually; no automatic pairing, no counterparty rule

**Status:** Accepted, 2026-08-21

## Context

Pairing invents relationships (`Paarung erfindet Verknuepfungen`) — two coincidentally equal amounts on the same day are not a transfer, and as long as only one account is imported, pairing finds nothing anyway. A false-positive counterparty rule would be worse than the error itself: it would **hide** real expenses from the report, and a report that is too low goes unnoticed by anyone (`ein zu niedriger Report faellt niemandem auf`).

## Decision

The user marks transfers; there is no automatic pairing and no counterparty rule.

## Consequences

Automatic pairing and a counterparty-based rule are both rejected, because a false match would silently hide real expenses in a way nobody would catch.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
