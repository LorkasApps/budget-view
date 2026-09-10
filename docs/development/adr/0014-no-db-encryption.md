---
title: No DB encryption, rely on Android FBE plus app sandbox
date: 2026-08-10
tags:
  - adr
description: The database is not encrypted at the field level; the threat model for a local single-user app is covered by Android FBE and app-scoped storage instead.
---

# 0014 — No DB encryption, rely on Android FBE plus app sandbox

**Status:** Accepted, 2026-08-10

## Context

Isar offers no built-in encryption. Field-level encryption would break queries and sorting, which is core to the app. The threat model for a local, single-user app is already covered by the OS plus app-scoped storage.

## Decision

`KEINE DB-Encryption`; rely on Android FBE (`Verlass auf Android FBE`) plus the app sandbox.

## Consequences

Field encryption is rejected as an alternative because it would break queries and sorting, which are core to the app. App-Lock (biometrics/PIN) remains available as an optional, later ticket.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
