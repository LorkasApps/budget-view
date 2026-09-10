---
title: Use fractal categorization, line-item overrides parent
date: 2026-08-10
tags:
  - adr
description: A line item can override the category of its parent transaction, to support drilling into a receipt (Kassenbon) by item.
---

# 0007 — Use fractal categorization, line-item overrides parent

**Status:** Accepted, 2026-08-10

## Context

A user requirement calls for drilling down into a receipt (`Kassenbon`) at the line-item level, which means a line item needs its own categorization independent of its parent transaction.

## Decision

Use fractal categorization: a line item overrides the category of its parent.

## Consequences

This satisfies the user requirement for `Kassenbon` drilldown; no rejected alternatives were recorded for this decision.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
