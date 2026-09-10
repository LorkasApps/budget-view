---
title: "Dev: nuke and rebuild on schema change; Prod: manual migration from v1.0"
date: 2026-08-10
tags:
  - adr
description: During development, a schema change simply nukes and rebuilds the local database; from v1.0, production requires a manual migration path.
---

# 0016 — Dev: nuke and rebuild on schema change; Prod: manual migration from v1.0

**Status:** Accepted, 2026-08-10

## Context

Early in the project, the overhead of building real migrations for every schema change would be disproportionate to the benefit.

## Decision

Dev: nuke and rebuild the database on a schema change (`Dev: nuke+rebuild bei Schema-Änderung`). Prod: manual migration from v1.0 onward (`Prod: manuelle Migration ab v1.0`).

## Consequences

The overhead in this early phase is small (`Frühphase-Overhead klein`), and the approach is clean starting from release (`sauber ab Release`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
