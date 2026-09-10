---
title: Repository-layer hook, every mutation calls adapter.enqueue()
date: 2026-08-10
tags:
  - adr
description: Every mutation calls adapter.enqueue() from the repository layer, giving sync a single, central hook instead of an app-wide interceptor.
---

# 0020 — Repository-layer hook, every mutation calls adapter.enqueue()

**Status:** Accepted, 2026-08-10

## Context

The change queue (0017, 0018) needs a single, reliable place where mutations get enqueued for sync.

## Decision

Repository-layer hook: every mutation calls `adapter.enqueue()`.

## Consequences

This is a central sync connection point (`Zentrale Sync-Anbindung`), without app-wide interceptor magic (`keine App-weite Interceptor-Magie`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
