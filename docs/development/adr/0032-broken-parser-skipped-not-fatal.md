---
title: A parser that throws or times out in canParse is skipped, not fatal
date: 2026-08-11
tags:
  - adr
description: If a parser's canParse throws or times out, it is skipped rather than aborting the whole import, so one broken plug-in cannot block the entire process.
---

# 0032 — A parser that throws or times out in canParse is skipped, not fatal

**Status:** Accepted, 2026-08-11

## Context

With multiple parser plug-ins competing via `canParse` (0031), a single misbehaving parser should not be able to take down the whole import.

## Decision

A parser that throws or times out in `canParse` is skipped, not fatal.

## Consequences

One broken plug-in must not block the whole import.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
