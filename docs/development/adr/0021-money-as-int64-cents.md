---
title: Represent money amounts as int64 cents
date: 2026-08-10
tags:
  - adr
description: Money amounts are stored as int64 cents to avoid floating-point errors in the finance domain.
---

# 0021 — Represent money amounts as int64 cents

**Status:** Accepted, 2026-08-10

## Context

The finance domain needs an exact representation for money amounts.

## Decision

Money amounts (`Geldbeträge`) = int64 cents.

## Consequences

This avoids floating-point errors in the finance domain (`Vermeidet Floating-Point-Fehler in Finance-Domain`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
