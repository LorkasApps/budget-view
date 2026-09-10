---
title: "Trade Republic money-market sweep (TRANSAKTIONSÜBERSICHT) is not imported"
date: 2026-08-24
tags:
  - adr
description: The money-market sweep table is skipped because its rows mirror the cash rows that triggered them, and importing both would count the statement twice and break balance reconciliation.
---

# 0122 — Trade Republic money-market sweep (TRANSAKTIONSÜBERSICHT) is not imported

**Status:** Accepted, 2026-08-24

## Context

Its rows mirror the cash rows that triggered them (a 38,71 € interest payment on the 1st comes back as a 38,71 € fund purchase on the 2nd), so both would count the statement twice and break balance reconciliation.

## Decision

The Trade Republic money-market sweep table (`TRANSAKTIONSÜBERSICHT`) is not imported.

## Consequences

To take it in anyway, a future parser would need to read that table's own `DATUM | ZAHLUNGSART | GELDMARKTFONDS | STÜCK | KURS PRO STÜCK | BETRAG` header the same way, and give up the reconciliation check.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
