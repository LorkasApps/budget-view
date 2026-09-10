---
title: "No OcrEmptyException; an empty result flows through, only OcrEngineException aborts"
date: 2026-08-17
tags:
  - adr
description: An empty OCR result is treated as valid and flows through rather than throwing a dedicated exception, keeping "zero line items is a valid scan" from ticket 016 intact.
---

# 0066 — No OcrEmptyException; an empty result flows through, only OcrEngineException aborts

**Status:** Accepted, 2026-08-17

## Context

"Zero line items is a valid scan" (`"Null Positionen ist ein gültiger Scan"`) from ticket 016 needs to remain true. The distinction that has value is "engine broken" vs. "receipt unreadable" (`"Engine kaputt" vs. "Bon unlesbar"`), not a second exception type.

## Decision

No `OcrEmptyException`; an empty result flows through, only `OcrEngineException` aborts.

## Consequences

The retry belongs to ticket 018, which builds the review surface (`das Retry gehört zu 018, das die Review-Fläche baut`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
