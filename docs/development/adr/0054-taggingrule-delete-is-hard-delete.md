---
title: TaggingRule.delete really deletes, no soft-delete
date: 2026-08-13
tags:
  - adr
description: TaggingRule.delete performs a real delete rather than a soft-delete, following the same logic as ImportedSource, because an archived rule that keeps suggesting would be pointless.
---

# 0054 — TaggingRule.delete really deletes, no soft-delete

**Status:** Accepted, 2026-08-13

## Context

An archived rule that keeps suggesting matches would be pointless (`Eine archivierte Regel, die weiter vorschlägt, wäre sinnlos`) — the same logic as `ImportedSource` (0042).

## Decision

`TaggingRule.delete` really deletes (`löscht echt`), no soft-delete.

## Consequences

This follows the same logic as `ImportedSource` (0042): deleting is the real business function for a rule that must stop suggesting.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
