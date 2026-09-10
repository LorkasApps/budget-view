---
title: Sync stub as interface plus local change queue (op-log)
date: 2026-08-10
tags:
  - adr
description: The sync layer starts as an interface backed by a local change queue (op-log), which validates the design without a cloud connection.
---

# 0017 — Sync stub as interface plus local change queue (op-log)

**Status:** Accepted, 2026-08-10

## Context

Cloud sync is deferred (see 0003), but the local-first design around it still needs to be validated before a cloud backend exists.

## Decision

Sync stub = interface plus a local change queue, i.e. an op-log (`Sync-Stub = Interface + lokale Change-Queue (Op-Log)`).

## Consequences

This validates the design without a cloud connection (`Validiert Design ohne Cloud-Anbindung`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
