---
title: "windowMonths = null means the whole history, no -1 sentinel as the ticket suggested"
date: 2026-08-18
tags:
  - adr
description: windowMonths uses null to mean the whole history rather than the ticket-suggested -1 sentinel, following the 2026-08-12 convention that "not set" is null everywhere in this schema.
---

# 0089 — windowMonths = null means the whole history, no -1 sentinel as the ticket suggested

**Status:** Accepted, 2026-08-18

## Context

This follows the 2026-08-12 decision (0039): "not set" is `null` everywhere in this schema. Two spellings for the same meaning cost more than the special case (`Zwei Schreibweisen für dieselbe Bedeutung kosten mehr als der Sonderfall`).

## Decision

`windowMonths = null` means "whole history" (`ganze Historie`), not a `-1` sentinel as the ticket suggested.

## Consequences

The ticket-suggested `-1` sentinel is rejected in favor of the existing schema-wide `null` convention.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
