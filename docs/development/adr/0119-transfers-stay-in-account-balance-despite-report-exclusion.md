---
title: Transfers stay in the account balance, even though they fall out of the report
date: 2026-08-21
tags:
  - adr
description: Transfers are excluded from the report but included in account balance, since the money really moved and a balance without them would be wrong — the one place where the report exclusion does not apply.
---

# 0119 — Transfers stay in the account balance, even though they fall out of the report

**Status:** Accepted, 2026-08-21

## Context

The money really moved; a balance without transfers would be wrong (`Das Geld ist wirklich gewandert, ein Saldo ohne sie waere falsch`).

## Decision

Transfers stay in the account balance, even though they fall out of the report.

## Consequences

This is the **only** place where the exclusion does not apply (`Die **einzige** Stelle, an der der Ausschluss nicht gilt`) — which is why it stands as its own test in the balance suite and not just a comment (`deshalb steht das als eigener Test in der Balance-Suite und nicht nur als Kommentar`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
