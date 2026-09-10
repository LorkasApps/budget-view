---
title: "Unit price is set only when amount / quantity lands on the cent, otherwise null"
date: 2026-08-17
tags:
  - adr
description: A derived unit price is only shown when amount divided by quantity lands exactly on the cent; otherwise it stays null, since an invented price would look like captured data in the form.
---

# 0072 — Unit price is set only when amount / quantity lands on the cent, otherwise null

**Status:** Accepted, 2026-08-17

## Context

A derived price that nobody actually printed would look like captured data in the form (`sieht im Formular aus wie erfasste Daten`).

## Decision

Unit price is set only when `amount / quantity` lands exactly on the cent, otherwise `null`.

## Consequences

The mismatch remains a warning in the sheet, per the 2026-08-13 decision (0047).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
