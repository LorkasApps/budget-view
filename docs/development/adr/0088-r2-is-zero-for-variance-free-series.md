---
title: "r2 = 0 for a variance-free series, not 1.0 and not NaN"
date: 2026-08-18
tags:
  - adr
description: A perfectly flat series reports r2 = 0 rather than 1.0 or NaN, since ssTot = 0 would otherwise compute 0/0 and 1.0 would misleadingly read as a perfect fit that explains nothing.
---

# 0088 — r2 = 0 for a variance-free series, not 1.0 and not NaN

**Status:** Accepted, 2026-08-18

## Context

For a flat series, `ssTot = 0`, and the formula would produce `0/0`. `1.0` would read as a perfect fit even though nothing was actually explained (`\`1.0\` würde als perfekte Anpassung gelesen, obwohl nichts erklärt wurde`).

## Decision

`r2 = 0` for a variance-free series, not `1.0` and not `NaN`.

## Consequences

`1.0` is rejected because it would falsely read as a perfect fit; `NaN` is rejected because it would surface as an unhandled `0/0` result.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
