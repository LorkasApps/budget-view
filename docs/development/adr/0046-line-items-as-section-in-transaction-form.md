---
title: "Line items sit as a section in TransactionFormScreen, no separate detail screen"
date: 2026-08-13
tags:
  - adr
description: Line items are edited as a section inside TransactionFormScreen's edit mode rather than on a dedicated detail screen, since the form already owns the persisted uuid a line item needs.
---

# 0046 — Line items sit as a section in TransactionFormScreen, no separate detail screen

**Status:** Accepted, 2026-08-13

## Context

The form already owns the persisted uuid that a line item needs (`Das Formular besitzt die persistierte uuid, die eine Position braucht`); a separate detail screen would have cost only a navigation hop and a rework of the list tests (`ein Detail-Screen hätte nur einen Navigations-Hop und einen Umbau der Listen-Tests gekostet`).

## Decision

Line items sit as a section in `TransactionFormScreen` (edit mode), with no separate detail screen.

## Consequences

The dedicated detail-screen alternative is rejected for now. This will be revisited when ticket 016 needs the receipt (`Kassenbon`) scan entry point (`Wird geprüft, wenn 016 den Kassenbon-Scan-Einstieg braucht`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
