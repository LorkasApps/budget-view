---
title: Unsavable candidates are skipped at confirm, not presented to the repository
date: 2026-08-17
tags:
  - adr
description: Candidates that cannot be saved are skipped when the user confirms rather than being submitted to the repository, keeping a LineItemInvalid failure from happening mid-persist with half-written rows.
---

# 0074 — Unsavable candidates are skipped at confirm, not presented to the repository

**Status:** Accepted, 2026-08-17

## Context

The review toggle is disabled while a row is incomplete (`Der Review-Toggle ist deaktiviert, solange eine Zeile unvollständig ist`). A `LineItemInvalid` failure in the middle of persisting would be the same outcome via the more expensive path (`derselbe Ausgang auf dem teureren Weg`) — with half-written line items.

## Decision

Candidates that cannot be saved are skipped at confirm, not presented to the repository.

## Consequences

This avoids a `LineItemInvalid` failure mid-persist, and the half-written line items that would result.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
