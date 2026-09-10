---
title: "Scan entry point is a button in LineItemsSection, no detail screen"
date: 2026-08-17
tags:
  - adr
description: The receipt-scan entry point is a button inside LineItemsSection rather than a detail screen, because the flow is fully modal and needs no dedicated screen surface.
---

# 0059 — Scan entry point is a button in LineItemsSection, no detail screen

**Status:** Accepted, 2026-08-17

## Context

This answers the checkpoint from the 016 clause of decision 0046: the flow is entirely modal and needs no dedicated screen surface (`der Flow ist komplett modal und braucht keine eigene Screen-Fläche`). A detail screen would have required reworking the list tests that 015/019 had just finished (`hätte die von 015/019 gerade fertiggestellten Listen-Tests umgebaut`).

## Decision

Scan entry point is a button in `LineItemsSection`, no detail screen.

## Consequences

The list tests completed by tickets 015/019 stay intact, since a detail screen would have forced reworking them.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
