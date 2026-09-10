---
title: Failed Trade Republic reconciliation refuses the whole statement, while the ING parser only warns
date: 2026-08-24
tags:
  - adr
description: A Trade Republic statement that fails balance reconciliation is refused entirely rather than warned about, because its movements telescope off the balance column, making the endpoint check the only defense against a dropped or misread row.
---

# 0125 — Failed Trade Republic reconciliation refuses the whole statement, while the ING parser only warns

**Status:** Accepted, 2026-08-24

## Context

TR movements are derived from the balance column and therefore telescope — their sum always equals the last balance minus the opening one, so the endpoint check is the only thing that catches a dropped or misread row.

## Decision

Failed Trade Republic reconciliation refuses the whole statement, while the ING parser only warns.

## Consequences

A statement that fails the endpoint check cannot be trusted row by row either, so a partial import is not offered.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
