---
title: "A real settings screen sits behind a Mehr tile, instead of hanging data lists directly on the Mehr tab"
date: 2026-08-20
tags:
  - adr
description: Settings get a real screen behind a Mehr tile rather than being hung directly off the Mehr tab, so configuration keeps one home once an app-lock toggle arrives, at the accepted cost of three navigation levels for a single item today.
---

# 0104 — A real settings screen sits behind a Mehr tile, instead of hanging data lists directly on the Mehr tab

**Status:** Accepted, 2026-08-20

## Context

Configuration keeps one home once the app-lock toggle arrives — otherwise preferences and data lists would sit in different places (`sonst stehen Präferenzen und Datenlisten an verschiedenen Orten`).

## Decision

A real settings screen sits behind a `Mehr` tile, instead of hanging data lists directly on the `Mehr` tab.

## Consequences

Accepted cost: three levels (`Mehr` → `Einstellungen` → list) for what is today a single item (`für heute eine Zeile`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
