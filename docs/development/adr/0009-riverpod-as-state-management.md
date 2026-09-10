---
title: Use Riverpod as state management
date: 2026-08-10
tags:
  - adr
description: Riverpod was picked for state management because it is compile-safe, includes dependency injection, and fits Isar's reactive patterns.
---

# 0009 — Use Riverpod as state management

**Status:** Accepted, 2026-08-10

## Context

At the start of the project, a state-management approach had to be chosen that would fit Isar's reactive query patterns.

## Decision

Use Riverpod as state management.

## Consequences

Riverpod is compile-safe, includes dependency injection, and fits Isar's reactive patterns.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
