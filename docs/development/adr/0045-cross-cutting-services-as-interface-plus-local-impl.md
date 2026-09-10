---
title: Cross-cutting services are an interface plus a Local implementation
date: 2026-08-12
tags:
  - adr
description: "Cross-cutting services (SyncAdapter, DuplicateChecker) are split into an interface plus a Local implementation, so widget tests can run without Isar, which never completes inside testWidgets's fake-async zone."
---

# 0045 — Cross-cutting services are an interface plus a Local implementation

**Status:** Accepted, 2026-08-12

## Context

Isar never finishes inside the fake-async zone that `testWidgets` runs in (`das in der Fake-Async-Zone von \`testWidgets\` nie fertig wird`), so widget tests cannot exercise a cross-cutting service that talks to Isar directly.

## Decision

Cross-cutting services (`Querschnitts-Services`) are structured as an interface plus a `Local` implementation (e.g. `SyncAdapter`, `DuplicateChecker`).

## Consequences

This allows widget tests without Isar (`Erlaubt Widget-Tests ohne Isar`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
