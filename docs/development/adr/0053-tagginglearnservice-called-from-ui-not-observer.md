---
title: "TaggingLearnService.learnFrom is called from UI paths, not an observer on TransactionRepository.save"
date: 2026-08-13
tags:
  - adr
description: TaggingLearnService.learnFrom is invoked from three UI call sites rather than an observer in TransactionRepository.save, for the same reason the Restposten reconcile call avoids a repository hook.
---

# 0053 — TaggingLearnService.learnFrom is called from UI paths, not an observer on TransactionRepository.save

**Status:** Accepted, 2026-08-13

## Context

The same reasoning as the `Restposten` reconcile decision (0050) applies: a hook in the repository would have turned `Transaction → Tagging` around (`ein Hook im Repository hätte \`Transaction → Tagging\` gedreht`).

## Decision

`TaggingLearnService.learnFrom` is called from the UI paths, not via an observer in `TransactionRepository.save`.

## Consequences

There are three call sites (form, inline quick-pick, import persist — `Formular, Inline-Quickpick, Import-Persist`). If a future call site forgets the call, learning is lost, but nothing becomes inconsistent (`vergisst eine künftige Stelle den Aufruf, geht Lernen verloren, aber nichts wird inkonsistent`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
