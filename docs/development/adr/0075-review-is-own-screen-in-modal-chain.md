---
title: Review is its own screen inside the modal chain, not another dialog
date: 2026-08-17
tags:
  - adr
description: The scan-review UI is a dedicated screen within the existing modal chain rather than a further dialog, since editing, toggling and categorizing rows does not fit into a dialog.
---

# 0075 — Review is its own screen inside the modal chain, not another dialog

**Status:** Accepted, 2026-08-17

## Context

Editing rows, toggling them on/off, and categorizing them does not fit into a dialog (`passt nicht in einen Dialog`).

## Decision

Review is its own screen within the modal chain, not another dialog.

## Consequences

The screen returns the list into the already-existing `confirm(edited:)` seam; the flow's `listenManual` subscription survives the push, and so do the photo bytes (`die \`listenManual\`-Subscription des Flows überlebt den Push, die Foto-Bytes also auch`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
