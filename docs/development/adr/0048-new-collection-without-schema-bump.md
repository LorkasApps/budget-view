---
title: New collection without bumping kDbSchemaVersion
date: 2026-08-13
tags:
  - adr
description: Adding the new line-item collection does not bump kDbSchemaVersion, since it is purely additive and Isar creates the collection on open; a bump would have nuked the dev DB with no benefit.
---

# 0048 — New collection without bumping kDbSchemaVersion

**Status:** Accepted, 2026-08-13

## Context

The change is purely additive (`Rein additiv`) — Isar creates the collection when it opens (`Isar legt die Collection beim Öffnen an`).

## Decision

New collection without a bump of `kDbSchemaVersion`.

## Consequences

A bump would have nuked the dev database and cost test data, without any offsetting benefit (`Ein Bump hätte in Dev die DB genukt und Testdaten gekostet, ohne Gegenwert`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
