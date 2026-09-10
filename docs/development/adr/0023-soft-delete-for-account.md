---
title: Soft-delete for Account via an archived flag
date: 2026-08-10
tags:
  - adr
description: Account deletion is a soft-delete via an archived flag, so history is preserved and the operation stays sync-friendly.
---

# 0023 — Soft-delete for Account via an archived flag

**Status:** Accepted, 2026-08-10

## Context

Deleting an account must not destroy its history, and the operation needs to be sync-friendly.

## Decision

Soft-delete for `Account` (archived flag).

## Consequences

History is preserved (`Historie bleibt erhalten`), and the approach is sync-friendly (`sync-freundlich`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
