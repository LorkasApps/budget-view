---
title: Category delete is blocked when children or transactions exist
date: 2026-08-10
tags:
  - adr
description: Deleting a category is blocked while it still has children or transactions, forcing an explicit move instead of silent data loss.
---

# 0025 — Category delete is blocked when children or transactions exist

**Status:** Accepted, 2026-08-10

## Context

Deleting a category that still has children or transactions attached risks silent data loss if those are not handled explicitly first.

## Decision

Category delete is blocked when children or transactions exist (`Category Delete blockiert wenn Kinder oder Transaktionen vorhanden`).

## Consequences

This forces an explicit move (`Erzwingt explizites Umziehen`) instead of silent data loss (`kein Datenverlust`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
