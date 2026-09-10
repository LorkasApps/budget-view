---
title: "`Transaction.merchant` alongside `counterparty`, not instead of it; tagging keys on `taggingKey = merchant ?? counterparty`, exactly one rule per transaction"
date: 2026-08-24
tags:
  - adr
description: "Transaction.merchant is added as a field beside counterparty rather than replacing it, since counterparty feeds the dedupe hash and must not depend on a parser heuristic that changes over time; tagging keys on merchant when present, falling back to counterparty."
---

# 0134 — `Transaction.merchant` alongside `counterparty`, not instead of it; tagging keys on `taggingKey = merchant ?? counterparty`, exactly one rule per transaction

**Status:** Accepted, 2026-08-24

## Context
`counterparty` is the identity of the transaction and feeds the dedupe hash — tied to a parser heuristic, a re-import after any pattern change would generate new hashes and count existing transactions as new. A collector-payee rule (`Sammelzahler-Regel`) running in parallel would keep growing its `hitCount` across every merchant, suggest a random category on every unrecognized row, and make the count in the rule list from ADR 0025 misleading.

## Decision
`Transaction.merchant` is added alongside `counterparty`, not instead of it. Tagging keys on `taggingKey = merchant ?? counterparty`, exactly one rule per transaction. The rule list shows `taggingKey`; the form and import preview keep showing the real counterparty: the list shows meaning, the form shows fact.

## Consequences
`counterparty` stays stable for deduplication regardless of how merchant-extraction heuristics evolve, and the rule list in 0025 keeps a meaningful, non-misleading count.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
