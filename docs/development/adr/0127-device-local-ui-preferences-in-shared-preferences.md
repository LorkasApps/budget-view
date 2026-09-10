---
title: "Device-local UI preferences live in shared_preferences, not in Isar and not in AppMeta"
date: 2026-08-24
tags:
  - adr
description: Device-local UI preferences use shared_preferences instead of Isar or AppMeta, since an Isar collection would force syncing a device-local choice or breaking the SyncableEntity contract, and AppMeta's role is identity, not preferences.
---

# 0127 — Device-local UI preferences live in shared_preferences, not in Isar and not in AppMeta

**Status:** Accepted, 2026-08-24

## Context

The choice is device-local, so an Isar collection would force either syncing a preference (wrong once a second device exists) or breaking the `SyncableEntity` contract every other entity keeps. `AppMeta` carries identity (`schemaVersion`, `installId`, `createdAt`), and a UI preference beside a schema version would blur its role.

## Decision

Device-local UI preferences live in `shared_preferences`, not in Isar and not in `AppMeta`.

## Consequences

This also avoids a schema bump. Accepted cost: one dependency, and `DevTools.wipeDatabase` does not clear it. A later App-Lock toggle inherits this home.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
