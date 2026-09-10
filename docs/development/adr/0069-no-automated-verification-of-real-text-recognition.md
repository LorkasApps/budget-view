---
title: No automated verification of real text recognition; umlauts are checked on-device
date: 2026-08-17
tags:
  - adr
description: There is no automated test of real ML Kit text recognition; umlaut handling is checked manually on-device, since the plugin has no binding in the test VM and a synthetic image would not exercise a real thermal-print receipt's path.
---

# 0069 — No automated verification of real text recognition; umlauts are checked on-device

**Status:** Accepted, 2026-08-17

## Context

The plugin has no binding in the test VM, and a synthetically rendered image exercises a path that no real thermal-print receipt (`Thermodruck-Bon`) takes — the same argument that got the fixture PDFs removed (see 0035).

## Decision

No automated verification of real text recognition; umlauts are checked on the device (`Umlaute werden am Gerät geprüft`).

## Consequences

Unit tests cover what we actually own: mapping, error wrapping, file lifecycle (`Mapping, Fehler-Wrapping, Datei-Lebenszyklus`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
