---
title: "Transaction.categoryAutoSuggested introduced already in 013, before 014 sets it true"
date: 2026-08-13
tags:
  - adr
description: Transaction.categoryAutoSuggested is added in ticket 013 even though only ticket 014 will ever set it to true, because the learn hook must be able to read it to avoid self-reinforcing suggestions.
---

# 0055 — Transaction.categoryAutoSuggested introduced already in 013, before 014 sets it true

**Status:** Accepted, 2026-08-13

## Context

The learn hook must be able to read this field, otherwise an accepted suggestion would reinforce itself (`sonst verstärkt sich ein akzeptierter Vorschlag selbst`).

## Decision

`Transaction.categoryAutoSuggested` is introduced already in 013, even though only 014 will set it to `true`.

## Consequences

The field is additive; existing data reads `false` — no schema bump is needed (`Feld ist additiv, Altdaten lesen \`false\` — kein Schema-Bump`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
