---
title: Choose a PDF parser via confidence ranking, user may override
date: 2026-08-11
tags:
  - adr
description: Each PDF parser reports a confidence via canParse (0.0-1.0); the highest-ranked one is picked by default, but the user may override the top pick.
---

# 0031 — Choose a PDF parser via confidence ranking, user may override

**Status:** Accepted, 2026-08-11

## Context

With a plug-in system for PDF parsers (0006), the app needs a way to pick which parser handles a given PDF, without hard-wiring any single bank's format and while acknowledging that heuristics can be wrong.

## Decision

Parser choice per PDF via confidence ranking (`canParse` 0.0–1.0); the user may override the top pick.

## Consequences

This avoids bank lock-in, at the accepted cost that the heuristic ranking can be wrong — which is why the user retains an override.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
