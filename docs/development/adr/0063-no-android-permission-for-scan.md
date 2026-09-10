---
title: No Android permission for the scan
date: 2026-08-17
tags:
  - adr
description: The receipt scan needs no declared Android permission, since Photo Picker (API 33+) and ACTION_IMAGE_CAPTURE need none, and a declared CAMERA permission would only trigger an unwanted runtime prompt.
---

# 0063 — No Android permission for the scan

**Status:** Accepted, 2026-08-17

## Context

Photo Picker (API 33+) and `ACTION_IMAGE_CAPTURE` need no permission; a declared `CAMERA` permission would only create the runtime prompt in the first place (`würde die Runtime-Abfrage erst erzeugen`).

## Decision

No Android permission is declared for the scan.

## Consequences

Boundary accepted: for camera captures, `image_picker` keeps its own plugin-internal temp file that our code never sees (`hält für Kamera-Captures eine plugin-eigene Temp-Datei, die unser Code nie sieht`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
