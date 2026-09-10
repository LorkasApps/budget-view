---
title: No fixture PDFs, verify parsers via balance reconciliation against real statements
date: 2026-08-11
tags:
  - adr
description: Parser verification uses balance reconciliation (Saldo-Abstimmung) against real bank statements in an env-gated harness, because a synthetic PDF cannot reproduce ING's real text-layer quirks.
---

# 0035 — No fixture PDFs, verify parsers via balance reconciliation against real statements

**Status:** Accepted, 2026-08-11

## Context

A PDF generated with the `pdf` package does not reproduce ING's text-layer quirks — padded words (`gepolsterte Wörter`), swallowed parentheses (`geschluckte Klammern`), split `TextLine`s (`gesplittete TextLines`). Testing against such a synthetic PDF would exercise a code path the real extractor never takes. Real data must also stay outside git.

## Decision

No fixture PDFs (`Keine Fixture-PDFs`); parser verification is done via balance reconciliation (`Saldo-Abstimmung`) against real statements, in an env-gated harness.

## Consequences

Layout logic instead hangs off synthetic word coordinates. Real data stays outside git (`Realdaten bleiben außerhalb von git`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
