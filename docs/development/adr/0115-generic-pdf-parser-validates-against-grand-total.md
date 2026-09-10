---
title: Generic PDF parser validates itself against the grand total, not sender vocabulary
date: 2026-08-21
tags:
  - adr
description: parseReceiptPdf recognizes no receipt by brand; it works from coordinates, format patterns and the absolute rule that no item can exceed the grand total, making it robust against unrelated page content without vocabulary maintenance.
---

# 0115 — Generic PDF parser validates itself against the grand total, not sender vocabulary

**Status:** Accepted, 2026-08-21

## Context

`parseReceiptPdf` recognizes no receipts by brand (`erkennt keine Bons nach Marke`); it works directly from coordinates (positions, price column), format patterns (three lines per price, `drei Zeilen pro Preis`) and absolute bounds (no item > grand total).

## Decision

The generic PDF parser validates itself against the grand total, instead of relying on sender vocabulary.

## Consequences

The logic is robust against page filler (`robust gegen Seitenfutter`) — mail headers, registration numbers, URLs that happen to compose into an amount all fall out because they exceed the bound. This costs neither maintenance nor a vocabulary (`Das kostet weder Wartung noch ein Vokabular`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
