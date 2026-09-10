---
title: Credits are subtracted from the total, not deleted as line items
date: 2026-08-21
tags:
  - adr
description: "A credit (Gutschrift) row is summed into creditCents and compared against candidates + printedTotal, instead of being deleted as a line item, since LineItem carries no sign and a receipt only knows amounts."
---

# 0117 — Credits are subtracted from the total, not deleted as line items

**Status:** Accepted, 2026-08-21

## Context

`LineItem` has no sign — a receipt only knows amounts (`ein Beleg kennt nur Beträge`). A `Pfand` or `Gutschrift` token builds into the grand total. In the OCR parser this was a bug: the total-mismatch warning fired incorrectly because the line items did not shrink (`die Summen-Warnung schlug falsch an, weil die Positionen nicht schrumpften`).

## Decision

Credits (`Gutschriften`) are subtracted from the total, not deleted as line items.

## Consequences

Now, a credit row is summed into `creditCents`, and the review screen compares `candidates + credits` against `printedTotal`. A credit row does not import as a line item, but as a correction to the invoice (`Ein Gutschrift-Zeile importiert nicht als Position, sondern als Korrektur der Rechnung`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
