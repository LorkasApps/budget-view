---
title: The printed total is read, but never imported
date: 2026-08-21
tags:
  - adr
description: A receipt's printed grand total is read for review comparison but never imported as a line item, since it would double-count the whole receipt otherwise.
---

# 0110 — The printed total is read, but never imported

**Status:** Accepted, 2026-08-21

## Context

The printed total is the sum of the line items — imported as a row it would count the whole receipt twice (`als Zeile importiert wuerde sie den ganzen Bon doppelt zaehlen`). Its value serves the review screen as a check against the kept line items, and is the only signal on the receipt that does not depend on row grouping (`das einzige Signal auf dem Bon, das nicht von der Zeilengruppierung abhaengt`).

## Decision

The printed total is read, but never imported as a line item.

## Consequences

The mismatch warning falls silent once the user changes the selection, because then a difference is intentional (`Die Warnung verstummt, sobald der Nutzer die Auswahl aendert, denn dann ist eine Differenz gewollt`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
