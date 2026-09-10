---
title: "The merchant is read from both occurrences in the payment reference; the one with fewer spaces wins"
date: 2026-08-24
tags:
  - adr
description: "ING wraps the payment reference (Verwendungszweck) mid-word inconsistently between debits and credits, so the merchant is extracted from both occurrences and the spelling with fewer embedded spaces is kept, since normalizeForMatching would otherwise treat a broken spelling as a distinct merchant."
---

# 0135 — The merchant is read from both occurrences in the payment reference; the one with fewer spaces wins

**Status:** Accepted, 2026-08-24

## Context
ING breaks the payment reference (`Verwendungszweck`) mid-word, and systematically differently depending on direction: on a direct debit (`Lastschrift`) the second spelling is clean (`bei Picnic GmbH`), on a credit (`Gutschrift`) the first one is (`. Picnic GmbH,`). Neither position is reliable. The choice is not cosmetic: `normalizeForMatching` collapses runs of whitespace but keeps single spaces, so `picnic g mbh` and `picnic gmbh` would become two separate rule keys for the same store — exactly the problem ADR 0047 was meant to end. Verified against a real January statement: 13 of 60 rows carried a merchant, all unbroken.

## Decision
The merchant is read from both occurrences in the payment reference; whichever spelling has fewer spaces wins.

## Consequences
This prevents a single merchant from splitting into multiple tagging rules due to a mid-word line break, keeping the guarantee from ADR 0047 intact.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
