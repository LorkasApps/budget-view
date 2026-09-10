---
title: Category is reachable from both the import edit dialog and the row chip
date: 2026-08-21
tags:
  - adr
description: The same category-edit interaction is deliberately exposed in two places — the import edit dialog and the row chip — both writing through setRowCategory so an override counts the same either way.
---

# 0112 — Category is reachable from both the import edit dialog and the row chip

**Status:** Accepted, 2026-08-21

## Context

The same interaction in two places would normally be avoided. Here, what matters is where users look for it: a row is corrected in the dialog, and a wrong suggested category is the most common reason to open it (`eine falsche Vorschlags-Kategorie ist der haeufigste Grund ihn zu oeffnen`).

## Decision

Category is reachable both in the import edit dialog **and** on the row chip.

## Consequences

Both paths write via `setRowCategory`, so an override from the dialog does not count differently than one from the row (`damit ein Override aus dem Dialog nicht anders zaehlt als einer aus der Zeile`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
