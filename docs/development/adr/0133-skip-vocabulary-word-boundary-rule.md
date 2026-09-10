---
title: "Skip vocabulary matches at word start or word end; `zwischensumme` is explicitly excluded"
date: 2026-08-24
tags:
  - adr
description: "Receipt skip vocabulary now matches at the start or the end of a word, because German compounds carry the keyword at least as often at the end (Endsumme); zwischensumme is explicitly excluded from the summe suffix match to avoid it being read as the grand total."
---

# 0133 — Skip vocabulary matches at word start or word end; `zwischensumme` is explicitly excluded

**Status:** Accepted, 2026-08-24

## Context
German compounds carry the keyword at least as often at the end as at the start: `Endsumme` was not recognized as a sum (`Summe`) by the prefix-only rule, and without a sum neither the checksum (`Checksumme`) nor the plausibility limit can engage. A free substring match would have hit inside unrelated words. The exclusion is the flip side of the same change: `zwischensumme` (`Zwischensumme`) ends in `summe` and would otherwise have been read as the grand total.

## Decision
Skip vocabulary matches at the start of a word **or** at its end; `zwischensumme` is explicitly excluded from that end-of-word `summe` match.

## Consequences
A known edge case remains: a purchased `Pfandflasche` (deposit bottle) reads as a credit — this is to be corrected against real receipts as they appear, not fixed in advance.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
