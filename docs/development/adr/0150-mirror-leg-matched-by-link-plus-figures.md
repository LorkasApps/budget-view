---
title: "An imported row is matched against an app-written mirror leg by the counterpart link plus amount and a ±5-day window, never by the dedupe hash"
date: 2026-09-22
tags:
  - adr
description: "The third duplicate layer narrows candidates by counterpartUuid and kind == transfer before comparing figures, then matches on the exact amount and a booking date within five days either side, because the dedupe hash contains the counterparty and the bank writes a different one than the app wrote."
---

# 0150 — An imported row is matched against an app-written mirror leg by the counterpart link plus amount and a ±5-day window, never by the dedupe hash

**Status:** Accepted, 2026-09-22

## Context
Ticket 042 writes the counter-leg of a transfer on the target account. When that
account's own statement is imported later, the same movement arrives a second time and
the existing duplicate guard cannot see it: the dedupe hash keys on amount, booking day
and normalised counterparty (ADR 0028), and the imported row carries the bank's own text
rather than the `Umbuchung von <Konto>` the app generated. So the hash is structurally
unusable for this case.

Matching on figures alone would be worse than useless — two coincidentally equal amounts
on one day are not a transfer, which is exactly why ADR 0141 made the pair a written link
instead of read-time matching. The link is therefore the first filter, not the last.

Exact-day matching would quietly find nothing: the app writes the mirror with the source
leg's date, while the receiving bank often books a day or two later. Since the user
confirms the replacement anyway, a generous window with both dates visible is safer than
a narrow one that silently misses.

The collision needs **both** accounts to be importable, which today is exactly one pair,
ING Giro ↔ TR Cash (ADR 0129). Narrow, but real.

## Decision
Candidates are narrowed by `counterpartUuid != null` and `kind == transfer` on the target
account **before any figure is compared**, so only legs the app wrote as a mirror can
match and an ordinary booking never does. Within that set the exact signed amount and a
booking date within **±5 days** pick the row. The window is day-based, not
instant-based: a leg saved through the form carries a time of day while an imported row
does not.

The warning names both dates and both texts, and the user decides between `Ersetzen`
(emphasised) and `Beide behalten`.

## Consequences
The query is cheap because the link filter eliminates nearly everything first, and it
cannot invent a connection between two unrelated bookings. The window will occasionally
present a leg the user then rejects — acceptable, since nothing is replaced without
confirmation. A transfer whose money left the app carries no `counterpartUuid` and is
therefore never offered.

## Evidence
- `lib/features/transaction/domain/transaction_repository.dart:102` — `findTransferLegsNear`:
  the link and kind filters precede the amount and date comparison, and the day-based
  window is computed there
- `lib/features/import/domain/duplicate_checker.dart:26` — the third method on the
  `DuplicateChecker` interface, beside the hash and document layers
- `lib/features/transaction/import/domain/import_flow_controller.dart:551` — where the
  import flow asks, per row
- `lib/features/transaction/import/presentation/pdf_import_screen.dart:148` —
  `_resolveMirrorLeg`, the dialog naming both dates and both texts
- `test/features/import/domain/duplicate_checker_test.dart` — group
  `mirror legs (ticket 048)`: window edges, an unpaired transfer, a regular booking, a
  differing amount, a soft-deleted leg
