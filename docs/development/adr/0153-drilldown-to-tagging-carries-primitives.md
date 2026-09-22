---
title: "The new Drilldown → Tagging edge carries primitives; Tagging never learns what a LineItem is"
date: 2026-09-22
tags:
  - adr
description: "learnFromPosition takes a description string, a category uuid and a bool rather than a LineItem, so suggesting and learning per position adds one directed edge without dragging another feature's entity into Tagging — the same restraint that keeps Tagging holding a category by uuid alone."
---

# 0153 — The new `Drilldown → Tagging` edge carries primitives; Tagging never learns what a `LineItem` is

**Status:** Accepted, 2026-09-22

## Context
Ticket 056 suggests a category per scanned or hand-entered position and learns the user's
choice back. Both surfaces live in Drilldown — the scan review screen and the line-item sheet —
and `dependencies.md` had no `Drilldown → Tagging` edge before this.

The obvious API would have been `learnFromPosition(LineItem)`, symmetric with the existing
`learnFrom(Transaction)`. That symmetry is misleading. `learnFrom` takes a `Transaction` because
Tagging genuinely depends on the transaction feature — `taggingKey`, `kind` and
`categoryAutoSuggested` are all read off the entity, and the edge `Tagging → Transaction` is
recorded for exactly that. Accepting a `LineItem` would add a second such dependency, and
Tagging would then know two of the app's entities while deliberately knowing nothing about
`Category` beyond a uuid.

There is also a practical asymmetry: a scan candidate is not a `LineItem` at all. It is a
transient `LineItemCandidate` that may never be persisted, so an entity-shaped API would have
forced the scan path to build a throwaway entity purely to satisfy a signature.

## Decision
`learnFromPosition({required description, required categoryUuid, required wasSuggested})` takes
primitives. The edge points `Drilldown → Tagging`, one direction, no cycle, and Tagging imports
nothing from Drilldown.

The guards stay inside Tagging rather than being duplicated at the two Drilldown call sites, so
"what teaches" remains one decision in one place.

## Consequences
The scan review and the line-item sheet call the same method with the same three values, and a
third surface could do so without touching Tagging.

`wasSuggested` is a parameter rather than a stored field. On the booking side the equivalent is
persisted (`Transaction.categoryAutoSuggested`) because a booking is edited later by paths that
do not know its history. A position has no such path: the candidate is transient, and the sheet
is always a hand edit. So nothing is stored, and no schema change was needed.

If Tagging ever needs to read a position — to count how often an article was corrected, say —
that is a new decision and not an extension of this one.

## Evidence
- `lib/features/tagging/domain/tagging_learn_service.dart` — `learnFromPosition` and the shared
  private `_learn` beneath it and `learnFrom`
- `lib/features/drilldown/scan/domain/receipt_scan_flow_controller.dart:13` — the import block,
  which names the edge and its restriction
- `lib/features/drilldown/presentation/line_item_edit_sheet.dart` — the sheet's `_save`, passing
  `_isSuggested`
- `docs/development/reference/dependencies.md` — the edge in the graph and its note
- `test/features/tagging/domain/tagging_learn_service_test.dart` — group
  `learning from a position (ticket 056)`
