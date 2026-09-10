---
title: "'Not set' is null everywhere, no empty-string sentinel"
date: 2026-08-12
tags:
  - adr
description: "'Not set' is represented as null everywhere in the schema, replacing the earlier decision to use parentUuid = '' — no field should carry two spellings of the same meaning."
---

# 0039 — 'Not set' is null everywhere, no empty-string sentinel

**Status:** Accepted, 2026-08-12

## Context

This was a user choice at ticket 011: `Transaction.categoryUuid` needs the same "not set" concept as `Category.parentUuid` already had, and having two spellings for the same meaning in one schema costs more than the nullable index — which was untested up to that point.

## Decision

"Not set" (`Nicht gesetzt`) is `null` everywhere, no empty-string sentinel. This replaces the earlier decision to use `parentUuid = ''`.

## Consequences

`Category.parentUuid` was retrofitted (`nachgezogen`) to this convention. Two spellings for the same meaning in one schema were rejected as costing more than the previously untested nullable index.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
