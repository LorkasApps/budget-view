---
title: Entity IDs are client-generated UUID v4
date: 2026-08-10
tags:
  - adr
description: Entity IDs are client-generated UUID v4 values, collision-free across devices, while Isar's auto-increment stays an internal storage index.
---

# 0019 — Entity IDs are client-generated UUID v4

**Status:** Accepted, 2026-08-10

## Context

With sync in mind (see 0017), entity identifiers need to be safe to generate on the client, across multiple devices, without a central authority.

## Decision

Entity IDs = UUID v4, client-generated (`client-generiert`).

## Consequences

This is collision-free across devices (`Kollisionsfrei über Geräte`); Isar's auto-increment remains an internal storage index only (`bleibt interner Storage-Index`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
