---
title: Price chart has a real time axis (days since first purchase) and does not anchor at 0
date: 2026-08-19
tags:
  - adr
description: The price-history chart uses a real time axis rather than an index axis, and does not anchor at zero, since purchases are irregular and a 20-cent move on a 1.49 EUR item would be invisible against a zero axis.
---

# 0099 — Price chart has a real time axis (days since first purchase) and does not anchor at 0

**Status:** Accepted, 2026-08-19

## Context

Purchases occur irregularly; an index axis would have implied even spacing and thereby invented a trend (`eine Index-Achse hätte gleichmäßige Abstände behauptet und damit einen Trend erfunden`). The forecast's zero-anchoring (0087) does not fit here: 20 cents on a 1.49 € item is the whole story, and it would be invisible against a zero axis (`20 Cent auf einen 1,49-€-Artikel sind die ganze Geschichte und an der Nullachse unsichtbar`).

## Decision

The price chart has a real time axis (days since the first purchase, `Tage seit dem ersten Kauf`) and does **not** anchor at 0.

## Consequences

An index axis is rejected as inventing an even-spacing trend that is not real; zero-anchoring, correct for the forecast, is rejected here as it would hide small but meaningful price moves.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
