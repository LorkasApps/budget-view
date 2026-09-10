---
title: Derive ING column boundaries from each page's header row, not hard-coded
date: 2026-08-11
tags:
  - adr
description: ING PDF column boundaries are derived from the header row of each page rather than hard-coded, so a bank layout change degrades to a warning instead of silent mis-parsing.
---

# 0036 — Derive ING column boundaries from each page's header row, not hard-coded

**Status:** Accepted, 2026-08-11

## Context

Hard-coding column boundaries for the ING statement layout risks silent mis-parsing if the bank changes its layout.

## Decision

Derive ING column boundaries from the header row of each page (`aus der Kopfzeile jeder Seite ableiten`), not hard-coded (`nicht hart kodieren`).

## Consequences

A layout change by the bank degrades to a warning instead of silent mis-parsing (`degradiert zu einer Warnung statt zu stillem Fehl-Parsing`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
