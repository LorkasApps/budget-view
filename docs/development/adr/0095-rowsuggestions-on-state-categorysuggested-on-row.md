---
title: "rowSuggestions is a map on ImportFlowState (next to rowMatches), categorySuggested lives on ImportRow"
date: 2026-08-19
tags:
  - adr
description: Suggestions are derived display data keyed per row index on the flow state, following the pattern rowMatches already sets, while provenance is a property of the row itself.
---

# 0095 — rowSuggestions is a map on ImportFlowState (next to rowMatches), categorySuggested lives on ImportRow

**Status:** Accepted, 2026-08-19

## Context

Suggestions are derived display data per row index and follow the pattern that `rowMatches` already sets (`Vorschläge sind abgeleitete Anzeigedaten pro Zeilenindex und folgen dem Muster, das \`rowMatches\` schon vorgibt`). Provenance, in contrast, is a property of the row itself.

## Decision

`rowSuggestions` is a map on `ImportFlowState` (alongside `rowMatches`); `categorySuggested` instead lives on `ImportRow`.

## Consequences

Provenance migrates into `Transaction.categoryAutoSuggested` when the row is persisted (`sie wandert beim Persistieren in \`Transaction.categoryAutoSuggested\``).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
