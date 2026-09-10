---
title: Document hash is taken over the raw bytes, downscale happens after
date: 2026-08-17
tags:
  - adr
description: The document hash used for re-import warnings is computed over the raw photo bytes before any downscaling, so an image-library update cannot shift the document's identity.
---

# 0061 — Document hash is taken over the raw bytes, downscale happens after

**Status:** Accepted, 2026-08-17

## Context

Otherwise, an update to the image library would shift the document's identity, and the re-scan warning from 0030 would no longer catch the same photo (`sonst verschiebt ein Update der Image-Lib die Dokument-Identität, und die Re-Scan-Warnung aus 009 greift für dasselbe Foto nicht mehr`).

## Decision

Document hash is computed over the raw bytes; downscaling happens only afterward.

## Consequences

The document's identity, and therefore the re-scan warning, is stable across image-library updates.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
