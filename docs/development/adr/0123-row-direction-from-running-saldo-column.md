---
title: Row direction comes from the running SALDO column, not which amount column holds the number
date: 2026-08-24
tags:
  - adr
description: Trade Republic row direction is derived from the running balance column rather than an x-boundary between ZAHLUNGSEINGANG and ZAHLUNGSAUSGANG, since that boundary would be the most fragile part of the parse.
---

# 0123 — Row direction comes from the running SALDO column, not which amount column holds the number

**Status:** Accepted, 2026-08-24

## Context

`ZAHLUNGSEINGANG` (x=368.7) and `ZAHLUNGSAUSGANG` (x=422.8) stand close together with right-aligned values, so an x-boundary between them would be the most fragile part of the parse.

## Decision

Row direction comes from the running `SALDO` column, not from which amount column holds the number.

## Consequences

The printed amount is checked against the balance step instead, which also catches a misread row.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
