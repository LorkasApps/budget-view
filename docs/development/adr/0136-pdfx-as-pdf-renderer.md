---
title: "`pdfx` as PDF renderer, not `pdfrx` or `pdf_render`"
date: 2026-08-24
tags:
  - adr
description: "pdfx is chosen as the PDF renderer because it renders on Android through the OS's own android.graphics.pdf.PdfRenderer with no bundled pdfium, unlike pdfrx (bundles pdfium) or the stale pdf_render; the accepted cost is pdfx pulling in an unused viewer's dependencies."
---

# 0136 — `pdfx` as PDF renderer, not `pdfrx` or `pdf_render`

**Status:** Accepted, 2026-08-24

## Context
`pdfx` renders on Android through the OS's own `android.graphics.pdf.PdfRenderer` — no bundled pdfium in the APK, which already stands at 98.7 MB. `pdfrx` bundles pdfium (`pdfium_flutter`, `pdfrx_engine`); `pdf_render` has been unchanged since 2024-08.

## Decision
`pdfx` is the PDF renderer, not `pdfrx` or `pdf_render`.

## Consequences
Accepted cost: `pdfx` pulls in `photo_view`, `web`, and `flutter_web_plugins` for a viewer that is never used. Writing roughly 30 lines of Kotlin against the same OS API directly was the alternative, and it was rejected in order to avoid owning native code on a path where R8 has already struck once (ADR 0034).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
