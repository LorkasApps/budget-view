---
title: Category requirement sits in the form, not the field
date: 2026-08-12
tags:
  - adr
description: Whether a category is required is enforced by the entry form, not the schema field, because manual entry requires a category while PDF import allows uncategorized rows.
---

# 0040 — Category requirement sits in the form, not the field

**Status:** Accepted, 2026-08-12

## Context

Manual entry requires a category, while PDF import allows uncategorized rows (`erlaubt unkategorisierte Zeilen`) — the same column needs two different rules depending on the entry path (`dieselbe Spalte mit zwei Regeln je Eingabeweg`).

## Decision

Category requirement (`Kategorie-Pflicht`) sits in the form (`im Formular`), not the field (`nicht im Feld`).

## Consequences

The same underlying field serves two entry paths with different validation rules, rather than the field itself enforcing a single rule for both.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
