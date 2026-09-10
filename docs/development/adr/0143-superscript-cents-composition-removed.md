---
title: "Composition of superscript cents is removed — replaces the 2026-08-24 entry (0132)"
date: 2026-09-08
tags:
  - adr
description: "Superscript-cent composition (ADR 0132) is removed after a dump of the same receipt it was based on showed ML Kit actually delivers each price as one already-merged token without a separator; a wordless row now reads its rightmost digit group as the price instead."
---

# 0143 — Composition of superscript cents is removed — replaces the 2026-08-24 entry (0132)

**Status:** Accepted, 2026-09-08

## Context
The dump of the very receipt ADR 0132 drew its assumption from disproves it: ML Kit delivers every price as **one** token with cents already merged, just without a separator (`129`, `1060`), and a promo row carries both prices in a single row (`649 479`). `3` and `79` on baselines 7 units apart do not occur in the real data. ADR 0132 was only verified against synthetic coordinates, so its removal represents no real loss. Keeping it as a fallback would have meant a second price path that fires exactly when the first fails, on geometry that nothing verifies.

## Decision
Composition of superscript cents is **removed** — this replaces the 2026-08-24 entry (ADR 0132). Instead, a **wordless** row reads its rightmost digit group as the price, last two digits as cents; the wordlessness keeps out `500g`, `2 x 125g`, `10er Pack`, and the minimum length of three digits keeps out quantity badges.

## Consequences
ADR 0132's superscript-cent composition and its row-tolerance carve-out are gone; price extraction in the OCR path is simpler and matches what real receipt dumps actually contain.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
