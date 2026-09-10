---
title: Forecast values below 0 are clamped to 0
date: 2026-08-18
tags:
  - adr
description: Forecast values are clamped at zero because a falling trend eventually crosses zero and negative expenses do not exist; the series carries magnitudes, so a negative point would be a logic error, not a sign.
---

# 0087 — Forecast values below 0 are clamped to 0

**Status:** Accepted, 2026-08-18

## Context

A falling trend eventually runs through zero (`Ein fallender Trend läuft irgendwann durch die Null`); negative expenses do not exist (`negative Ausgaben gibt es nicht`).

## Decision

Forecast values below 0 are clamped to 0.

## Consequences

The series carries magnitudes; a negative point would not be a legitimate sign but a logic error (`ein negativer Punkt wäre kein Vorzeichen, sondern ein Denkfehler`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
