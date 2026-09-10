---
title: OCR and parser contract are defined in 016, implementation follows in 017/018
date: 2026-08-17
tags:
  - adr
description: Ticket 016 defines the OCR and parser contract as a stub rather than cutting the flow short, because the controller itself is 016's real artifact and the handoff contracts were already scoped into the ticket.
---

# 0058 — OCR and parser contract are defined in 016, implementation follows in 017/018

**Status:** Accepted, 2026-08-17

## Context

The controller *is* the artifact of ticket 016 (`Der Controller *ist* das Artefakt von 016`). The alternative — 016 ending after the hash check — would have meant rebuilding the state machine twice, and the handoff contracts were already part of the ticket anyway (`die Handoff-Contracts standen ohnehin schon im Ticket`).

## Decision

The OCR and parser contract are created in 016; implementation follows only in 017/018 (a stub instead of cutting the flow, `Stub statt Flow-Schnitt`).

## Consequences

The rejected alternative — ending 016 after the hash check — would have rebuilt the state machine twice.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
