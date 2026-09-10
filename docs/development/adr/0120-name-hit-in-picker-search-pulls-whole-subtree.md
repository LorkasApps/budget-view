---
title: A name hit in picker search pulls the whole subtree, non-matching ancestors kept as path
date: 2026-08-24
tags:
  - adr
description: Matching a category name in picker search pulls its whole subtree, keeping non-matching ancestors visible as a path, since a parent's name reveals nothing about children like "Bio" or "Wochenmarkt".
---

# 0120 — A name hit in picker search pulls the whole subtree, non-matching ancestors kept as path

**Status:** Accepted, 2026-08-24

## Context

Searching a parent name reaches children whose names reveal nothing about the parent (`Bio`, `Wochenmarkt`) — exactly where a flat filter fails.

## Decision

A name hit in picker search pulls the whole subtree; non-matching ancestors are kept as a path.

## Consequences

Path preservation means no new half-interactive row state appears; the path row stays selectable and keeps its `+`.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
