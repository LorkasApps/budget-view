---
title: "Card acquirers are recognized via a name list (`_acquirers`), not via the shape of the payment reference"
date: 2026-09-10
tags:
  - adr
description: "Card acquirer detection uses a hand-maintained name list rather than the shape of the terminal reference, because an ordinary card payment (e.g. Kaufland) prints the identical <merchant>/<street>/<city>/<country> <timestamp> shape and a shape-based rule would fragment its tagging rule per branch."
---

# 0148 — Card acquirers are recognized via a name list (`_acquirers`), not via the shape of the payment reference

**Status:** Accepted, 2026-09-10

## Context
The terminal shape `<Händler>/<Straße>/<Ort>/<Land> <Zeitstempel>` prints an **ordinary** card payment the same way, and there the counterparty is already the store itself (`Lastschrift KAUFLAND` with `Kaufland Bergisch Gladbach//…`). A shape-based rule would also set a merchant there, and because `taggingKey` prefers the merchant, a `kaufland` rule would become one rule per branch — a regression for rows that already work correctly today. The shape does not indicate that a counterparty is a stand-in for the real merchant; only the name does.

## Decision
Card acquirers are recognized via a name list (`_acquirers`), not via the shape of the payment reference.

## Consequences
Accepted price: one entry per acquirer, extended by hand — in exchange, the logic is visible in one place instead of hidden inside a heuristic.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
