---
title: "Change-queue entry shape: {op, entity_type, entity_id, payload_json, ts}"
date: 2026-08-10
tags:
  - adr
description: Each change-queue entry carries op, entity_type, entity_id, payload_json and ts, a fine-grained shape standard for local-first sync.
---

# 0018 — Change-queue entry shape: {op, entity_type, entity_id, payload_json, ts}

**Status:** Accepted, 2026-08-10

## Context

The change queue (op-log) introduced in 0017 needs a concrete entry shape.

## Decision

Change-queue entry: `{op, entity_type, entity_id, payload_json, ts}`.

## Consequences

This is fine-grained (`Fein-granular`) and standard for local-first designs (`standard local-first`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
