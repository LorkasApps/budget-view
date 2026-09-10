---
title: Shared import artifacts live in their own Import domain, format-specific code stays put
date: 2026-08-12
tags:
  - adr
description: ImportedSource and the document hash move into a dedicated Import domain because both PDF and photo imports need them, while the ING parser stays where it is since it only needs PDF.
---

# 0044 — Shared import artifacts live in their own Import domain, format-specific code stays put

**Status:** Accepted, 2026-08-12

## Context

`ImportedSource` and the document hash are needed by both PDF *and* photo imports, while the ING parser only needs PDF (`der ING-Parser braucht nur PDF`).

## Decision

Shared import artifacts move into their own `Import` domain; format-specific code stays put (`formatspezifischer Code bleibt`).

## Consequences

Moving working ticket-008 code without functional gain was avoided (`Umziehen von funktionierendem 008-Code ohne funktionalen Gewinn vermieden`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
