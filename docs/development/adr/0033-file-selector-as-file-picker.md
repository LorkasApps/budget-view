---
title: "Use file_selector (not file_picker) as the file picker"
date: 2026-08-11
tags:
  - adr
description: file_selector was chosen over file_picker because it is the official Flutter package, the Android-only scope needs only single-file pick, and it has a smaller native surface.
---

# 0033 — Use file_selector (not file_picker) as the file picker

**Status:** Accepted, 2026-08-11

## Context

The app is Android-only (0010) and only needs to let the user pick a single file for import.

## Decision

Use `file_selector` (not `file_picker`) as the file picker.

## Consequences

`file_selector` is the official Flutter package; the Android-only scope needs only single-file pick, and it has a smaller native surface than the rejected alternative, `file_picker`.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
