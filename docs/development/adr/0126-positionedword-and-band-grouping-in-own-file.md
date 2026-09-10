---
title: "PositionedWord and band grouping live in their own file; words inside a band are ordered by visual line before x"
date: 2026-08-24
tags:
  - adr
description: PositionedWord and band grouping were extracted into a shared file once a second parser needed them, and band ordering was fixed to sort by visual line before x after a wrapped description interleaved with the line above it.
---

# 0126 — PositionedWord and band grouping live in their own file; words inside a band are ordered by visual line before x

**Status:** Accepted, 2026-08-24

## Context

The second parser is what made these shared. Sorting a band by `left` alone interleaved a wrapped description with the line above it — the transfer row read `Outgoing (DE0750…) transfer for Lukas Kochniss` and its payee fell back to the row type.

## Decision

`PositionedWord` and band grouping live in their own file; words inside a band are ordered by visual line before x.

## Consequences

The bug that motivated this — a wrapped description interleaving with the line above and misreading the payee — is fixed by ordering on visual line first.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
