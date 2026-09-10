---
title: "The result is the one number on this surface that shows its sign — plus red/green"
date: 2026-09-08
tags:
  - adr
description: "The report result number deliberately breaks the 2026-08-18 rule of showing magnitudes at the row edge, because a signless result carries no information while income and expense already get their direction from the column header; color doubles the sign rather than replacing it."
---

# 0146 — The result is the one number on this surface that shows its sign — plus red/green

**Status:** Accepted, 2026-09-08

## Context
This is a deliberate exception to the 2026-08-18 rule (magnitudes at the row edge): a result without a sign carries no information, while income and expenses already get their direction from the column header. The color is the convention already used by the transaction list (`colorScheme.error` / `Colors.green.shade700`), so it introduces no new visual language, and it doubles the sign rather than replacing it — the row does not depend on color perception.

## Decision
The result is the **one** number on this surface that shows its sign — plus red/green.

## Consequences
Zero stays sign-less and color-less: "nothing happened" and "balanced" are the same number, which is why an empty month gets no special state either.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
