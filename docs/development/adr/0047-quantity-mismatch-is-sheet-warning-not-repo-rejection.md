---
title: "quantity × unitPrice ≠ amount is a warning in the sheet, not a repo rejection"
date: 2026-08-13
tags:
  - adr
description: A mismatch between quantity times unit price and the stored amount surfaces as a warning in the sheet rather than a repository-level rejection, since discount and deposit rows deliberately break the product.
---

# 0047 — quantity × unitPrice ≠ amount is a warning in the sheet, not a repo rejection

**Status:** Accepted, 2026-08-13

## Context

Discount rows and deposit (`Pfand`) rows deliberately break the `quantity × unitPrice = amount` product (`brechen das Produkt absichtlich`).

## Decision

`quantity × unitPrice ≠ amount` is a warning in the sheet, not a repository rejection.

## Consequences

This follows the same pattern as the dedupe warning, which also sits in the form rather than the repository (`Folgt der Dedupe-Warnung, die auch im Formular sitzt statt im Repo`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
