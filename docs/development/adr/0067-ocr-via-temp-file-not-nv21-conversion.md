---
title: OCR runs over a dedicated, immediately deleted temp file instead of NV21 conversion in Dart
date: 2026-08-17
tags:
  - adr
description: OCR reads a dedicated temp file that is deleted right after, rather than converting the image to NV21 in Dart, because a self-written conversion bug would silently produce garbled text instead of a crash.
---

# 0067 — OCR runs over a dedicated, immediately deleted temp file instead of NV21 conversion in Dart

**Status:** Accepted, 2026-08-17

## Context

`InputImage.fromBytes` requires raw NV21 plus rotation on Android. Converting it ourselves means owning both YUV *and* EXIF rotation — a bug there would quietly produce garbled text instead of a crash (`ein Fehler dort liefert leise Buchstabensuppe statt eines Absturzes`).

## Decision

OCR runs over its own, immediately deleted temp file, instead of NV21 conversion in Dart.

## Consequences

This means the 016 promise "our code writes nothing to disk" (`"unser Code schreibt nichts auf Platte"`) no longer literally holds; the promise that actually matters — the photo is not kept — holds through the `finally` block (`die Zusage, die zählt (das Foto wird nicht behalten), hält durch das \`finally\``).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
