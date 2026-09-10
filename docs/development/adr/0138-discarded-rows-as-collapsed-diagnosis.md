---
title: "Discarded rows return to the review screen as collapsed diagnosis, not a debug dump"
date: 2026-08-24
tags:
  - adr
description: "Discarded receipt rows are shown in the review screen as a collapsed diagnosis section rather than removed as noise (035) or shown as a kDebugMode dump, since a debug dump would be absent in exactly the release build where the failure occurs."
---

# 0138 — Discarded rows return to the review screen as collapsed diagnosis, not a debug dump

**Status:** Accepted, 2026-08-24

## Context
Without them, a layout the parser cannot read looks like an empty receipt (`Bon`) — ADR 0035 had removed them as noise, which remains true for a well-read receipt, hence collapsed rather than gone entirely. A `kDebugMode` dump would be absent in exactly the release build where the failure occurs (a lesson from ADR 0034).

## Decision
Discarded rows come back into the review screen as collapsed diagnosis, not a debug dump. The rows are plain text, not candidates: nothing about them is selectable or savable.

## Consequences
A failing layout stays diagnosable in a release build, without reintroducing noise on receipts that parse correctly.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
