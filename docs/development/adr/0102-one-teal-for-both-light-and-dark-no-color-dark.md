---
title: "One teal (#009688) for both light and dark, no color_dark"
date: 2026-08-20
tags:
  - adr
description: A single teal is used for both light and dark launcher backgrounds instead of a separate color_dark, since the filled shape carries its own contrast and reads the same on either wallpaper.
---

# 0102 — One teal (#009688) for both light and dark, no color_dark

**Status:** Accepted, 2026-08-20

## Context

The filled shape carries its own contrast; the mark reads the same over light and dark launcher wallpapers (`Mark liest gleich über hellen und dunklen Launcher-Wallpapers`).

## Decision

One teal (`#009688`) is used for both light and dark, with no `color_dark`.

## Consequences

The splash screen uses the same teal, so startup flows into the app without a color jump (`Startup fließt ohne Farbsprung in die App`) — one check instead of two (`Eine Prüfung statt zwei`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
