---
title: "An alternative picked from the suggestion sheet counts as an override, not an acceptance (categoryAutoSuggested = false)"
date: 2026-08-19
tags:
  - adr
description: Picking an alternative from the category-suggestion sheet is recorded as an override rather than an acceptance, since an accepted suggestion is skipped by the learning loop and a deliberate correction must not be too.
---

# 0092 — An alternative picked from the suggestion sheet counts as an override, not an acceptance (categoryAutoSuggested = false)

**Status:** Accepted, 2026-08-19

## Context

`learnFrom` skips accepted suggestions so that a suggestion cannot reinforce itself. If the deliberately chosen second option also counted as an acceptance, its `hitCount` would stay put and it could never overtake the top suggestion — the user's correction would be ineffective (`die Korrektur des Users wäre wirkungslos`).

## Decision

An alternative picked from the suggestion sheet counts as an **override**, not an acceptance (`categoryAutoSuggested = false`).

## Consequences

The rejected alternative — treating the picked alternative as an acceptance too — would have left the learning loop unable to let a corrected choice ever overtake the incumbent top suggestion.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
