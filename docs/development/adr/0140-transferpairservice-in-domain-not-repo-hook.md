---
title: "Transfer pairing lives in `TransferPairService` (transaction/domain), called from UI paths, not in `TransactionRepository.save`"
date: 2026-09-07
tags:
  - adr
description: "Transfer pairing sits in a domain service called from UI paths rather than a repository save hook, because amount/date mirroring must stay a form-level rule that ADR 048 can override without propagating, and cascading delete needs a confirmation dialog a repository cannot show."
---

# 0140 — Transfer pairing lives in `TransferPairService` (transaction/domain), called from UI paths, not in `TransactionRepository.save`

**Status:** Accepted, 2026-09-07

## Context
Unlike the `Restposten` reconcile and the tagging-learn case (2026-08-13), no dependency edge would have been flipped here — both legs are transactions. Two other reasons decided it instead. First, mirroring amount and date must remain a form-level rule, because ADR 0048 replaces one mirrored leg with the bank's own numbers and must *not* propagate: money leaves one account on one day and arrives on another, and a fee may legitimately make the amounts diverge. An unconditional `save` invariant would have walled off ADR 0048. Second, the cascading delete needs a confirmation that names the other account, and a repository cannot show a dialog; a silent cascade underneath a UI that is still asking would be two answers to one question.

## Decision
Transfer pairing lives in `TransferPairService` (`transaction`/domain), called from the UI paths — not in `TransactionRepository.save`.

## Consequences
Accepted risk, same as 2026-08-13: a future write path could forget to call it — the countermeasure is a test that pins the delete site, not the compiler.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
