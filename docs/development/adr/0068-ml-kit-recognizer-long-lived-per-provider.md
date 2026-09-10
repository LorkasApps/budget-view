---
title: ML Kit recognizer is long-lived per provider, released via ref.onDispose
date: 2026-08-17
tags:
  - adr
description: The ML Kit text recognizer is allocated once for the app's lifetime per provider and released via ref.onDispose, following ML Kit's own recommendation over a per-photo allocation.
---

# 0068 — ML Kit recognizer is long-lived per provider, released via ref.onDispose

**Status:** Accepted, 2026-08-17

## Context

This follows ML Kit's own recommendation (`ML Kits eigene Empfehlung`): a native allocation for the app's lifetime, instead of one per photo (`eine native Allokation für die App-Lebenszeit statt einer pro Foto`).

## Decision

The ML Kit recognizer is long-lived per provider; release happens via `ref.onDispose`.

## Consequences

A per-photo allocation, the rejected alternative, would have gone against ML Kit's own guidance.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
