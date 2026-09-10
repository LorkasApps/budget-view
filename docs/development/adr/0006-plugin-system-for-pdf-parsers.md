---
title: Use a plug-in system for PDF parsers
date: 2026-08-10
tags:
  - adr
description: PDF parsers are structured as a plug-in system so import stays generic and no single bank is hard-wired into the app.
---

# 0006 — Use a plug-in system for PDF parsers

**Status:** Accepted, 2026-08-10

## Context

The app needs to import bank statement PDFs generically, without being locked to one bank's format.

## Decision

Use a plug-in system for PDF parsers.

## Consequences

Import stays generic and avoids bank lock-in.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
