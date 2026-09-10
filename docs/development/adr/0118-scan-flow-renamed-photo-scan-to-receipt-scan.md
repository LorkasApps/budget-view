---
title: "Scan flow renamed from photo_scan to receipt_scan, ReceiptPhotoScanFlowController to ReceiptScanFlowController"
date: 2026-08-21
tags:
  - adr
description: The scan flow and its controller were renamed because a receipt can be a photo or a text-layer PDF, and both paths run through the same controller and warning, making the old photo-specific name semantically wrong.
---

# 0118 — Scan flow renamed from photo_scan to receipt_scan, ReceiptPhotoScanFlowController to ReceiptScanFlowController

**Status:** Accepted, 2026-08-21

## Context

A receipt can be a photo or a PDF with a text layer. Both paths run through the same controller and the same warning. The old name would have made the PDF variant look like a special case — semantically wrong (`Der alte Name hätte die PDF-Variante als Spezialfall wirken lassen — das ist semantisch falsch`).

## Decision

The scan flow was renamed from `photo_scan` to `receipt_scan`; the flow controller from `ReceiptPhotoScanFlowController` to `ReceiptScanFlowController`.

## Consequences

The ticket was deliberately not patchworked from 009 to 012/013 to 018, but built only once the abstractions were in place (016 for the state machine, 017 for OCR, 018 for review, 033 for PDF). `ReceiptScanFlowController` is now the abstraction.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
