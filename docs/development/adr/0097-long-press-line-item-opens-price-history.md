---
title: "Long-press on a line item opens price history — a pure navigation edge, Drilldown → Analytics"
date: 2026-08-19
tags:
  - adr
description: Opening price history via a long-press on a line item is a pure navigation edge from Drilldown to Analytics, following the documented Account → Category precedent, rather than routing through TransactionFormScreen.
---

# 0097 — Long-press on a line item opens price history — a pure navigation edge, Drilldown → Analytics

**Status:** Accepted, 2026-08-19

## Context

This was a user choice at ticket 022. It follows the documented precedent `Account → Category` (the AppBar opens the category tree, with no other dependency, `sonst keine Abhängigkeit`). The alternative — hanging the callback off `TransactionFormScreen` — would only have moved the edge to `Transaction → Analytics` (`hätte die Kante nur auf \`Transaction → Analytics\` verschoben`).

## Decision

Long-press on a line item opens price history, as a pure navigation edge `Drilldown → Analytics`.

## Consequences

The rejected alternative — routing the callback through `TransactionFormScreen` — is noted as merely relocating the dependency edge rather than avoiding it.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
