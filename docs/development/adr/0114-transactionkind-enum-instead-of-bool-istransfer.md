---
title: "TransactionKind enum instead of bool isTransfer"
date: 2026-08-21
tags:
  - adr
description: Transaction kind is modeled as an enum rather than a boolean, since a securities purchase is the same class of case and a two-valued bool tends to get renamed rather than extended.
---

# 0114 — TransactionKind enum instead of bool isTransfer

**Status:** Accepted, 2026-08-21

## Context

A securities purchase (`Securities purchase`) is the same class of case as a transfer; a `bool` with two values tends to get renamed quickly rather than extended (`\`bool\` mit zwei Werten wird schnell umbenannt`).

## Decision

Use a `TransactionKind enum` instead of `bool isTransfer`.

## Consequences

Enum extension clarifies intent and costs nothing in the refactor (`Enum-Erweiterung klärt Intent und kostet im Refactor nichts`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
