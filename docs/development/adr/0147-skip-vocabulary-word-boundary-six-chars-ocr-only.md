---
title: "The OCR parser's skip vocabulary also matches within one edit step, from six characters of word length — the PDF parser stays exact"
date: 2026-09-08
tags:
  - adr
description: "OCR-parser skip vocabulary now matches within an edit distance of one for words of six or more characters, since misrecognized total-row labels (Bestelung, Gespat) slipped past the exact list and turned a credit into a fake line item; the PDF parser, which has no OCR noise, stays exact."
---

# 0147 — The OCR parser's skip vocabulary also matches within one edit step, from six characters of word length — the PDF parser stays exact

**Status:** Accepted, 2026-09-08

## Context
OCR returned total-row labels misspelled (`Bestelung`, `Gespat`), so the exact list failed to match and `Gespat -5,73` became a 5.73-euro line item. Adding literal misspellings just shifts the problem to the next scan, which misspells differently. The geometric alternative — sum labels sit at the left margin (x≈14), item names at x≈92 — was rejected because on a thermal receipt everything sits at the left margin and the rule would then hit every row. Six characters as the lower bound, because an edit step on a shorter word turns it into an unrelated one. A text layer has no noise to forgive.

## Decision
The OCR parser's skip vocabulary also matches within one edit step (Levenshtein distance 1), for words of six characters or more. The PDF parser stays exact.

## Consequences
Skip vocabulary remains per-parser (as established in ADR 0130): the OCR parser tolerates one recognition error per word, the PDF parser — reading a clean text layer — does not need to.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
