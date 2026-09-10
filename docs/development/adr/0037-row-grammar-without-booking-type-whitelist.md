---
title: Row grammar has no whitelist of booking types
date: 2026-08-11
tags:
  - adr
description: The ING row grammar uses date+amount to mark a new row and a bare date as value date (Valuta), instead of whitelisting known booking types, since the list of ING booking types is open-ended.
---

# 0037 — Row grammar has no whitelist of booking types

**Status:** Accepted, 2026-08-11

## Context

The list of ING booking types (`Buchungsarten`) is open-ended (`ist offen`); a whitelist would silently swallow unknown types (`würde unbekannte Typen unbemerkt verschlucken`).

## Decision

Row grammar without a whitelist of booking types (`Zeilengrammatik ohne Whitelist der Buchungsarten`): date+amount marks a new row, a bare date is a value date (`nacktes Datum = Valuta`).

## Consequences

Unknown booking types are handled structurally rather than by name, avoiding the risk of unbeknownst omissions that a whitelist would introduce.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
