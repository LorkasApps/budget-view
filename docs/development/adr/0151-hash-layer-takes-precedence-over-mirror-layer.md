---
title: "A row the dedupe hash already matched is never offered the mirror-leg replacement; the hash layer owns it"
date: 2026-09-22
tags:
  - adr
description: "The mirror-leg lookup runs only for rows the hash layer found nothing for, because a leg replaced in an earlier run carries the bank's fields and therefore hashes like the row — which is what keeps a settled replacement from being re-asked on every re-import."
---

# 0151 — A row the dedupe hash already matched is never offered the mirror-leg replacement; the hash layer owns it

**Status:** Accepted, 2026-09-22

## Context
After `Ersetzen` (ADR 0150) the mirror leg carries the bank's description, counterparty,
amount and date, and `TransactionRepository.save` recomputes the dedupe hash on every
write (ADR 0041). The replaced leg therefore hashes exactly like the row that replaced it.

But the leg also keeps its `counterpartUuid` and `kind == transfer`, because the pair is
still real. So it still satisfies every condition of the mirror-leg query, and a re-import
of the same statement would offer `Ersetzen` again for a question the user already
answered — while the ordinary duplicate warning fires for the same row at the same time.
Two markers, one row, one of them re-asking a settled decision.

The alternative considered was an explicit "already replaced" marker on the leg. Rejected:
it is a stored flag for something the hash already expresses, and ticket 056's reasoning
applies here too — a persisted flag needs a reason no derivable value can give.

## Decision
The mirror-leg lookup runs **only** for rows the hash layer found nothing for. A row with
a hash match is owned by the ordinary duplicate path and shows only that marker.

The two markers are therefore mutually exclusive by construction, and the header's
suspicious count is the union of both layers.

## Consequences
"A mirror leg the user already replaced is not offered again" needs no rule of its own —
it follows from the ordering. One query is saved per row that already has a hash match.

The cost: if the user replaces a leg and the bank later restates the same movement with a
*different* amount or date, that row matches neither layer and arrives as new. Correct, in
fact — a changed figure is a different booking, and the dedupe warning exists for the rest.

## Evidence
- `lib/features/transaction/import/domain/import_flow_controller.dart:546` — the `continue`
  that skips the mirror lookup once the hash layer matched, with the reason inline
- `lib/features/transaction/import/domain/import_flow_controller.dart:221` —
  `hasHashDuplicate` and `isSuspicious`: separate markers, one shared count
- `lib/features/transaction/import/presentation/pdf_import_screen.dart:534` — the mirror
  marker renders on `mirrorMatch` alone, beside the duplicate marker that renders on
  `suspicious`
- `test/features/transaction/import/pdf/pdf_dedupe_integration_test.dart` — test
  `a leg already replaced is a plain duplicate on the next import`
