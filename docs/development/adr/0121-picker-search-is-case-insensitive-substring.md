---
title: "Picker search is case-insensitive substring, not normalizeForMatching"
date: 2026-08-24
tags:
  - adr
description: "Category picker search stays a plain case-insensitive substring match — Bruehe does not find Brühe — kept separate from normalizeForMatching so umlaut handling stays intentional here, not a side effect of a shared function."
---

# 0121 — Picker search is case-insensitive substring, not normalizeForMatching

**Status:** Accepted, 2026-08-24

## Context

`normalizeForMatching` exists for machine comparison in dedupe and tagging; widening it later would silently change search behaviour.

## Decision

Picker search is case-insensitive substring, not `normalizeForMatching`; `Bruehe` does not find `Brühe`.

## Consequences

Separation keeps the contract: umlaut handling is intentional here, not a side effect of a shared function used elsewhere for machine comparison.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
