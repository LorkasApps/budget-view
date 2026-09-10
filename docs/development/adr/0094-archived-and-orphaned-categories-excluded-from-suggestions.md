---
title: Archived and orphaned categories fall out of suggestions
date: 2026-08-19
tags:
  - adr
description: Suggestions never offer archived or orphaned categories, since the picker itself does not offer either and a suggestion the user cannot repeat by hand is an offer into the void.
---

# 0094 — Archived and orphaned categories fall out of suggestions

**Status:** Accepted, 2026-08-19

## Context

The picker offers neither archived nor orphaned categories; a suggestion the user cannot repeat by hand is an offer into the void (`ein Vorschlag, den der User nicht von Hand wiederholen kann, ist ein Angebot ins Leere`).

## Decision

Archived and orphaned categories fall out of suggestions.

## Consequences

The underlying tagging rule itself stays stored and legal (`Die Regel selbst bleibt gespeichert und legal`); ticket 025 heals it (`025 heilt sie`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
