---
title: Photo bytes live outside Riverpod state, autoDispose plus listenManual for the flow
date: 2026-08-17
tags:
  - adr
description: Photo bytes are kept outside comparable Riverpod state; an autoDispose provider plus a manual listenManual subscription keeps the controller alive exactly for the flow's duration.
---

# 0062 — Photo bytes live outside Riverpod state, autoDispose plus listenManual for the flow

**Status:** Accepted, 2026-08-17

## Context

Bytes do not belong in a comparable state object (`Bytes gehören nicht in einen vergleichbaren State`).

## Decision

Photo bytes live outside Riverpod state; the provider is `autoDispose` plus a `listenManual` subscription that spans the flow's duration.

## Consequences

`autoDispose` forces discarding on exit; the manual subscription keeps the controller alive exactly as long as the flow (`hält den Controller genau so lange am Leben wie den Flow`). `state.holdsImage` mirrors the reference, so the rule stays testable (`damit die Regel testbar ist`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
