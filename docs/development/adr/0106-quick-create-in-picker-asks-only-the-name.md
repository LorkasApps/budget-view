---
title: "Quick-create in the picker only asks for the name; the parent is fixed by pressing +"
date: 2026-08-20
tags:
  - adr
description: Quick-create in the category picker only prompts for a name, with the parent already fixed by which + was pressed, since tapping a row already means "select" and a parent field would have stacked a second sheet on the picker.
---

# 0106 — Quick-create in the picker only asks for the name; the parent is fixed by pressing +

**Status:** Accepted, 2026-08-20

## Context

Tapping a row already means "select" (`Der Tap auf eine Zeile bedeutet schon „auswählen""`), so the parent needs its own gesture — a parent field would have stacked a second sheet on top of the picker (`ein Parent-Feld hätte ein zweites Sheet über dem Picker gestapelt`).

## Decision

Quick-create in the picker asks only for the name; the parent is fixed by which `+` was pressed.

## Consequences

Icon and color stay in the full form; otherwise the middle of quick entry would recreate exactly the form the user was trying to escape (`sonst wäre mitten in der Eingabe genau das Formular wieder da, dem der Nutzer entkommen wollte`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
