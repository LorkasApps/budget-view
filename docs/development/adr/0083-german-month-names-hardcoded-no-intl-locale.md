---
title: "German month names are hard-coded in date_format.dart, no intl locale dataset"
date: 2026-08-18
tags:
  - adr
description: German month names are hard-coded rather than sourced from an intl locale dataset, since DateFormat with month names would need initializeDateFormatting and a missing call would only fail at runtime.
---

# 0083 — German month names are hard-coded in date_format.dart, no intl locale dataset

**Status:** Accepted, 2026-08-18

## Context

`DateFormat` with month names would need `initializeDateFormatting`; a missing call to it would only surface at runtime (`ein fehlender Aufruf fliegt erst zur Laufzeit auf`).

## Decision

German month names are hard-coded in `date_format.dart`, with no `intl` locale dataset.

## Consequences

The file already avoids `intl` for `dd.MM.yyyy` formatting (`Die Datei vermeidet intl schon bei \`dd.MM.yyyy\``), so this keeps that avoidance consistent for month names too.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
