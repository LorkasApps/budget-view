---
title: Tagging rules can only be curated, not created by hand
date: 2026-08-20
tags:
  - adr
description: Tagging rules can only be curated from existing data rather than typed in by hand, because a mistyped matchValueNorm would never match while looking like a working rule in the list.
---

# 0105 — Tagging rules can only be curated, not created by hand

**Status:** Accepted, 2026-08-20

## Context

`matchValueNorm` is a normalized string (`normalizeForMatching`): a mistyped rule never matches, but looks like a working one in the list (`eine vertippte Regel greift nie, sieht in der Liste aber aus wie eine funktionierende`). The alternative — choosing from existing counterparties — would need a distinct query over counterparties that does not exist (`bräuchte ein Distinct-Query über Gegenseiten, das es nicht gibt`).

## Decision

Tagging rules can only be curated, not created by hand.

## Consequences

The rejected alternative, letting the user pick from existing counterparties directly, is blocked by the lack of a distinct-counterparty query.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
