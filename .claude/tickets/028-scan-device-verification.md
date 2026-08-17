# Device verification pass for the scan pipeline

| Field | Value |
|-------|-------|
| **Type** | TechDebt |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | None (016–018 are Done) |
| **Severity** | Medium |
| **Effort** | M |
| **Status** | Draft |

## Description
Tickets 016–018 shipped the whole receipt-scan pipeline, but its native half has never run: `make check` cannot touch `image_picker`, ML Kit, EXIF rotation, the Android manifest's model bundling, or the cache-directory temp file. The unit suites cover our own seams only — mapping, state machine, file lifecycle, heuristics against crafted coordinates.

This ticket is one walk through the pipeline on a real device with real receipts. It produces findings, not code: every defect becomes its own Bug ticket. Accuracy of the heuristic is explicitly part of it — the row-grouping tolerance was chosen against synthetic coordinates and wants tuning against real ML Kit output, which is only obtainable on a device.

## Risk if ignored
Every native assumption in 016–018 stays unproven. A missing model bundle, a rotation that ML Kit reads differently than assumed, or a grouping tolerance that merges two receipt rows all look identical from here: green tests, unusable feature. The longer the gap, the more tickets pile on top of an unverified base — 022 (item price trends) and 023 (unit-price normalization) both consume what this pipeline writes.

## Affected Domain(s)
Drilldown (scan pipeline), Import (the `ImportedSource` row each pass writes).

## Verification Strategy
Walk the checklist below once on a physical Android device, build via `make run`. Note the actual observation next to each item. Anything that deviates → Bug ticket referencing this one, with the observation as repro.

## Acceptance Criteria
- [ ] Camera path: "Kassenbon scannen" → Kamera opens without a permission prompt, capture returns to the flow
- [ ] Gallery path: picker opens (Photo Picker on API 33+), chosen image returns to the flow
- [ ] OCR umlauts (inherited from 017): a real receipt round-trips `Käse`, `Öl`, `Süß`, `Brühe` correctly in the review screen
- [ ] Rotation: a portrait capture is recognized as well as a landscape one — ML Kit reads EXIF through `InputImage.fromFilePath`, which is the assumption behind the temp-file detour
- [ ] Heuristic accuracy on ≥ 3 real receipts from different shops: note how many rows land `ok` / `ambiguous` / `unparsed`, and whether any two receipt rows were merged into one candidate
- [ ] Prices land on the right rows (rightmost-token rule holds against real column layout)
- [ ] Skip list catches the totals block of each receipt; no `Summe` / `MwSt` row becomes a position
- [ ] Review screen: toggles, row edit, "Zeile hinzufügen", "alle kategorisieren" all behave on a real list
- [ ] Confirm persists the kept rows to the booking with the right sign, and the Restposten row closes the gap (019)
- [ ] Re-scanning the same photo triggers the doc-hash warning (009), and proceeding notes "Erneuter Scan trotz Warnung"
- [ ] "Weiteren Bon scannen" runs a second pass on the same booking
- [ ] Cache directory holds no `scan_*.jpg` leftovers after several passes (the `finally` delete actually fires on device)

## Affected Tests
None — this ticket adds no automated test. Findings may add them via their own Bug tickets.

## Fixtures Needed
No — real receipts, kept out of git.
