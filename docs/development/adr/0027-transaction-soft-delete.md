---
title: Transaction uses soft-delete via a deleted flag
date: 2026-08-10
tags:
  - adr
description: Transaction deletion is a soft-delete via a deleted flag, so history is preserved and the operation stays sync-friendly.
---

# 0027 — Transaction uses soft-delete via a deleted flag

**Status:** Accepted, 2026-08-10

## Context

Deleting a transaction must not destroy its history, and the operation needs to be sync-friendly, matching the same approach already taken for `Account` (0023).

## Decision

Transaction: soft-delete (`deleted` flag).

## Consequences

History is preserved (`Historie bleibt`), and the approach is sync-friendly (`sync-freundlich`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
