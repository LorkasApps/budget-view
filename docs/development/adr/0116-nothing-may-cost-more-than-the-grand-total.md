---
title: Nothing may cost more than the grand total
date: 2026-08-21
tags:
  - adr
description: This absolute bound replaces a vocabulary for page filler, since an artifact line documenting no real transaction, or a mis-grouped row, will always exceed the printed total.
---

# 0116 — Nothing may cost more than the grand total

**Status:** Accepted, 2026-08-21

## Context

A page-filler line is by definition an artifact that documents no real transaction (`Ein Seitenfutter-Zeile ist per Definition ein Artefakt, das keine echte Transaktion dokumentiert`). An item that exceeds the total is either a row-grouping error or a foreign element (a mail header).

## Decision

Nothing may cost more than the grand total. This replaces the vocabulary approach for page filler (`Ersetzt das Vokabular für Seitenfutter`).

## Consequences

Regardless of the cause, the user sees the suspicious item in review, and if the receipt was misread, the suspect item surfaces there (`der User sieht ihn im Review, und wenn der Bon falsch gelesen wurde, taucht der verdächtige Artikel auf`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
