---
title: Category name is unique per parent, not globally
date: 2026-08-10
tags:
  - adr
description: Category names only need to be unique under their parent, not globally, so names like "Einkauf" or "Rückerstattung" can be reused under different parents.
---

# 0026 — Category name is unique per parent, not globally

**Status:** Accepted, 2026-08-10

## Context

Names such as "Einkauf" (purchase) or "Rückerstattung" (refund) are generic enough to make sense under several different parent categories.

## Decision

Category name is unique per parent (`unique per Parent`), not global (`nicht global`).

## Consequences

This allows reuse of names like "Einkauf" / "Rückerstattung" under different parents (`Wiederverwendung von "Einkauf" / "Rückerstattung" unter versch. Parents`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
