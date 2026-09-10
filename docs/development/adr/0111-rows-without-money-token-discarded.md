---
title: "Rows without a money token are discarded, instead of offered as unparsed"
date: 2026-08-21
tags:
  - adr
description: A row with no amount cannot be an item, so address and header blocks are dropped structurally rather than by keyword, and LineItemParseState.unparsed was removed as unreachable.
---

# 0111 — Rows without a money token are discarded, instead of offered as unparsed

**Status:** Accepted, 2026-08-21

## Context

A row without an amount cannot be an item (`Eine Zeile ohne Betrag kann kein Artikel sein`); address and header blocks disappear structurally instead of by keyword (`verschwinden damit strukturell statt per Stichwort`).

## Decision

Rows without a money token are discarded, instead of being offered as `unparsed`.

## Consequences

`LineItemParseState.unparsed` was no longer reachable via any input path and was removed together with its display — the same line as the deleted `No*` fallbacks (0076). The "here was text I couldn't read" hint is deliberately given up (`Aufgegeben wird der Hinweis „hier stand Text, den ich nicht lesen konnte""`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
