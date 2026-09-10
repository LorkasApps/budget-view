---
title: "Restposten protection via a save() guard plus a test, not the compiler"
date: 2026-08-13
tags:
  - adr
description: Protection for the Restposten (remainder) line is enforced by a save() guard plus a test rather than the compiler, since Dart has no package-private visibility to lean on.
---

# 0051 — Restposten protection via a save() guard plus a test, not the compiler

**Status:** Accepted, 2026-08-13

## Context

Dart has no package-private visibility; privacy is library-wide (`Dart hat kein package-private; Privatheit ist library-weit`). The alternatives — putting the reconciler in the same file as the repository, or a sentinel token in the call — cost more readability than the protection is worth (`kosten mehr Lesbarkeit als der Schutz wert ist`).

## Decision

`Restposten` protection is enforced via a `save()` guard plus a test, not the compiler.

## Consequences

The rejected alternatives (same-file reconciler, sentinel token) were judged to cost more in readability than the protection they would buy.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
