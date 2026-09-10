---
title: Scan candidates carry unsigned magnitudes, the flow sets the sign at persist time
date: 2026-08-17
tags:
  - adr
description: Scan candidates hold unsigned amounts; the flow applies the sign when persisting, replacing the transactionSign parameter from ticket 016 with a single transformation point instead of two.
---

# 0070 — Scan candidates carry unsigned magnitudes, the flow sets the sign at persist time

**Status:** Accepted, 2026-08-17

## Context

A receipt knows no sign (`Ein Bon kennt keine Vorzeichen`), `LineItemValidation.amount` explicitly rejects negatives, and ticket 015 attaches the sign to the transaction, not the line item (`015 hängt das Vorzeichen an die Buchung`).

## Decision

Scan candidates carry unsigned magnitudes; the flow sets the sign when persisting.

## Consequences

This replaces the `transactionSign` parameter from ticket 016: one transformation point instead of two (`eine Transformationsstelle statt zwei`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
