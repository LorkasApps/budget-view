---
title: "Drilldown shows the parent's own amounts as its own row, \"X (direkt)\", including a donut segment"
date: 2026-08-18
tags:
  - adr
description: A parent category's own amounts appear as a dedicated "X (direkt)" row with a donut segment in the drilldown, so the drilldown total matches the tapped row's rollupCents exactly.
---

# 0082 — Drilldown shows the parent's own amounts as its own row, "X (direkt)", including a donut segment

**Status:** Accepted, 2026-08-18

## Context

This was a user choice at ticket 020. This keeps the drilldown total identical to the `rollupCents` of the tapped row (`Damit ist die Drilldown-Summe identisch mit dem \`rollupCents\` der angetippten Zeile`); the alternative (showing it only in the header) would have based donut percentages on a different total than the one displayed (`hätte Donut-Prozente auf eine andere Basis bezogen als die angezeigte Gesamtsumme`).

## Decision

In the drilldown, the parent's own amounts appear as their own row, "X (direkt)", including a donut segment.

## Consequences

The rejected alternative — showing the parent's own amount only in the header — would have based the donut percentages on a different total than the one displayed.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
