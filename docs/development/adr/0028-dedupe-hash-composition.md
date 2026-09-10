---
title: Dedupe hash is SHA-256 over amountCents, bookingDate and normalized counterparty
date: 2026-08-10
tags:
  - adr
description: The duplicate-detection hash is SHA-256 over amountCents plus bookingDate plus a normalized counterparty; empty-counterparty collisions surface as a UI warning for the user to decide on.
---

# 0028 — Dedupe hash is SHA-256 over amountCents, bookingDate and normalized counterparty

**Status:** Accepted, 2026-08-10

## Context

The duplicate-detection approach from 0008 needs a concrete hash composition.

## Decision

Dedupe hash: SHA-256 over `amountCents` + `bookingDate` (date) + normalized `counterparty`.

## Consequences

This was a user choice (`User-Wahl`); collisions where the counterparty is empty are shown as a UI warning, and the user decides (`Kollisionen bei leerem counterparty werden als UI-Warnung dargestellt, User entscheidet`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
