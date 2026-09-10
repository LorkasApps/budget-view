---
title: ImportedSource.delete really deletes, no soft-delete
date: 2026-08-12
tags:
  - adr
description: Unlike everywhere else in the schema, ImportedSource.delete performs a real delete, because a warning-only row that stays archived and keeps warning would be pointless.
---

# 0042 — ImportedSource.delete really deletes, no soft-delete

**Status:** Accepted, 2026-08-12

## Context

The `ImportedSource` row exists so that a re-import can warn the user (`Die Zeile existiert, damit ein Re-Import warnt`). An archived row that keeps warning would be pointless (`Eine archivierte Zeile, die weiter warnt, wäre sinnlos`).

## Decision

`ImportedSource.delete` really deletes (`löscht echt`), unlike the soft-delete used everywhere else (`kein Soft-Delete wie sonst überall`).

## Consequences

Deleting *is* the actual business function here (`Löschen *ist* hier die Fachfunktion`), a deliberate exception to the soft-delete convention used for `Account` (0023) and `Transaction` (0027).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
