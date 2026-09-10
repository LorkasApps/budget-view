---
title: Reserve Supabase as the future sync layer, prep only
date: 2026-08-10
tags:
  - adr
description: Supabase is reserved as the future cloud-sync layer, but cloud sync itself is deferred and only prepared for.
---

# 0003 — Reserve Supabase as the future sync layer, prep only

**Status:** Accepted, 2026-08-10

## Context

At the start of the project, a future cloud-sync layer had to be picked, even though cloud sync itself is not being built yet.

## Decision

Use Supabase as the future sync layer (prep only).

## Consequences

This was a user choice, and cloud sync is deferred; no alternatives or trade-offs were recorded for this decision.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
