---
title: "Report entry is an AppShell with NavigationBar + IndexedStack, not an icon in the accounts AppBar"
date: 2026-08-18
tags:
  - adr
description: The report gets a dedicated AppShell with a NavigationBar and IndexedStack rather than an AppBar icon, since forecast, price trends and settings all need a surface, and IndexedStack keeps filter and scroll state alive across tabs.
---

# 0077 — Report entry is an AppShell with NavigationBar + IndexedStack, not an icon in the accounts AppBar

**Status:** Accepted, 2026-08-18

## Context

This was a user choice at ticket 020. Ticket 021 (forecast), 022 (price trends) and 024/025 (settings) all need a surface anyway; the AppBar could not have carried them individually (`die AppBar hätte sie einzeln nicht getragen`).

## Decision

Report entry is an `AppShell` with `NavigationBar` plus `IndexedStack`, not an icon in the accounts AppBar.

## Consequences

`IndexedStack` is used instead of rebuilding per tab switch, so that filter state and scroll position of both tabs survive (`damit Filterstand und Scrollposition beider Tabs überleben`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
