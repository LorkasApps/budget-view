---
title: Category tree has free roots, the sign of the amount is the direction
date: 2026-08-10
tags:
  - adr
description: The category tree allows free root categories, and the sign of the amount encodes direction, avoiding duplicate categories for refund cases like deposits or utility settlements.
---

# 0024 — Category tree has free roots, the sign of the amount is the direction

**Status:** Accepted, 2026-08-10

## Context

Refund-like cases — deposit returns (`Pfand`), utility cost settlements (`Nebenkosten`) — would otherwise need duplicate categories for the outgoing and incoming direction of the same kind of transaction.

## Decision

Category tree (`Kategorie-Baum`): free roots (`freie Roots`), the sign of the amount is the direction (`Sign des Betrags = Richtung`).

## Consequences

This avoids duplicate categories for refund cases such as deposits (`Pfand`) and utility settlements (`Nebenkosten`) (`Vermeidet Kategorie-Duplikate für Rückzahlungs-Cases`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
