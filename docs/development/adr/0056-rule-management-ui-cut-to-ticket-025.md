---
title: Rule-management UI from ticket 013 is cut into its own ticket 025
date: 2026-08-13
tags:
  - adr
description: The rule-management UI is split out of ticket 013 into ticket 025, since there is no settings surface yet and building it as a by-product of a storage ticket would have designed it by accident.
---

# 0056 — Rule-management UI from ticket 013 is cut into its own ticket 025

**Status:** Accepted, 2026-08-13

## Context

There is no settings surface yet (`Es gibt noch keine Settings-Fläche`); building the rule-management UI as a by-product of a storage ticket would have designed it by accident (`hätte sie versehentlich entworfen`). Ticket 024 needs the same surface — whichever lands first builds it (`wer zuerst landet, baut sie`).

## Decision

The rule-management UI from ticket 013 is cut (`geschnitten`) into its own ticket, 025.

## Consequences

Ticket 013 no longer builds this UI as a side effect; ticket 024 and ticket 025 share the same surface, built by whichever lands first.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
