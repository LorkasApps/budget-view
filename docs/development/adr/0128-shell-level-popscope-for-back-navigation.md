---
title: "Back at a secondary tab selects Konten, back at Konten leaves the app — PopScope at shell level, no confirmation"
date: 2026-08-24
tags:
  - adr
description: Back navigation follows Android's bottom-navigation convention via a single shell-level PopScope, rejecting both a visited-tab history walk and a per-tab Navigator that would have rebuilt the shell instead of fixing it.
---

# 0128 — Back at a secondary tab selects Konten, back at Konten leaves the app — PopScope at shell level, no confirmation

**Status:** Accepted, 2026-08-24

## Context

This is Android's convention for bottom navigation. Walking the visited tab order was rejected because the user cannot tell how deep they are, and three tab switches meaning three back presses reads as the app refusing to close. A `Navigator` per tab was also rejected, since it would rebuild the shell rather than fix it: pushed screens would then live inside the tab and the nav bar would stay visible where it is covered today.

## Decision

Back at a secondary tab selects `Konten`; back at `Konten` leaves the app — implemented as a single `PopScope` at shell level, with no confirmation dialog.

## Consequences

Nothing is at stake on leaving, since everything saves immediately, so no confirmation is needed. The rejected alternatives (visited-tab history, per-tab `Navigator`) would have added confusing depth or duplicated the shell's job.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
