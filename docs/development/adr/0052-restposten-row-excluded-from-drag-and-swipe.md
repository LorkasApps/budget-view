---
title: "Restposten row is excluded from drag and swipe, rather than rejected on attempt"
date: 2026-08-13
tags:
  - adr
description: The Restposten (remainder) row cannot be dragged or swiped at all, instead of rejecting the gesture on attempt, since a row that swipes away and comes back reads as a bug.
---

# 0052 — Restposten row is excluded from drag and swipe, rather than rejected on attempt

**Status:** Accepted, 2026-08-13

## Context

A row that swipes away and then comes back reads as a bug (`Eine Zeile, die wegwischt und zurückkommt, liest sich als Bug`).

## Decision

The `Restposten` row is excluded from drag and swipe entirely, instead of rejecting the gesture when attempted.

## Consequences

Reorder only writes the regular rows; the reconciler pins the managed row back to the bottom afterward (`Reorder schreibt nur die regulären Zeilen, der Reconciler pinnt die verwaltete danach wieder nach unten`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
