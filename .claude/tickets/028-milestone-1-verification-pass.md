# Verification pass for milestone 1 (device + visual)

| Field | Value |
|-------|-------|
| **Type** | TechDebt |
| **Epic** | None |
| **Domain** | Infra |
| **Blocked By** | None (all collected features are Done) |
| **Severity** | Medium |
| **Effort** | XL |
| **Status** | Draft |

## Description
Everything milestone 1 built that `make check` structurally cannot judge, collected
into one walk through the app. Two kinds of gap:

- **Native halves** — `image_picker`, ML Kit, EXIF rotation, `file_selector`, the
  Android manifest, the cache directory. No test VM binding exists for them.
- **Rendering and feel** — whether a chart paints, a label stays legible, a row
  overflows, a gesture is discoverable. Widget tests assert data and presence,
  never a frame.

Per the user's working style, the visual pass happens **once for the whole app**
rather than per ticket. Every ticket that closed on green tests with an unrendered
surface deposited its check here instead of asking for its own device round.

This ticket produces findings, not code: every deviation becomes its own Bug
ticket referencing this one, with the observation as repro.

## Risk if ignored
Green tests and an unusable feature look identical from here. The unverified base
also compounds: 022 and 023 consume what the scan pipeline writes, and every new
screen lands in a shell whose navigation has never been touched by a finger.

## Affected Domain(s)
All of them — Infra (shell, boot), Account, Transaction, Category, Drilldown
(positions + scan), Import, Analytics.

## Verification Strategy
One pass on a physical Android device, `make run`. Note the observation next to
each item; deviations become Bug tickets. Work area by area — the order below
follows the app's own flow, so the data each later area needs already exists.

## Acceptance Criteria

### Boot + shell (001–003, 020, 021)
- [ ] Cold start opens the account list, no crash while Isar opens
- [ ] Bottom nav switches `Konten` / `Report` / `Mehr` (029 moved the rare surfaces behind the menu); each tab keeps its scroll position and filter state across switches (that is what the `IndexedStack` is for)
- [ ] `Mehr` lists `Prognose` and `Preistrends`, and back returns to the menu rather than to a tab
- [ ] German umlauts render correctly in every screen title and label
- [ ] Amounts read as `1.234,56 €` throughout (`de_DE`, non-breaking space before the symbol)
- [ ] Launcher icon + splash, once 027 is Done — add its findings here rather than opening a second pass

### Accounts (004, 005)
- [ ] List renders, total header sums the accounts, per-account balance matches opening balance + bookings
- [ ] A negative balance is visibly in the error colour, not just differently signed
- [ ] Swipe → archive asks first; long-press on an archived row restores it
- [ ] Form: name validation, type dropdown, EUR input accepting `,` and `.`, date picker refusing the future

### Transactions (006, 011)
- [ ] List is newest-first with the saldo header; swipe → delete confirms
- [ ] Row `CategoryChip` quick-pick reassigns inline and the row updates immediately
- [ ] Form: Ausgabe/Einnahme toggle drives the sign, missing category shows `Kategorie erforderlich` in red
- [ ] Uncategorized-only filter in the app bar actually narrows the list

### Categories (010, 012)
- [ ] Tree expands/collapses; the drag handle reorders siblings **without** stealing the long-press that archives (the two gestures share one row — this is the point of the explicit `ReorderableDragStartListener`)
- [ ] Reorder across levels is refused with the snackbar, not silently applied
- [ ] Icon grid (24) and colour grid (12) both render and persist the choice
- [ ] Deleting a category that has children or bookings shows the German block message with the right counts
- [ ] Picker sheet: `Erbt von der Buchung (…)` label appears for line-items, `Keine Kategorie` where allowed

### PDF import (007, 008, 009)
- [ ] `file_selector` opens and returns a real ING statement
- [ ] The statement parses: row count and amounts match the paper, `Neuer Saldo − Alter Saldo` reconciles
- [ ] A statement from a **second** layout / another bank is either parsed or rejected with a readable message — never silently half-parsed
- [ ] Preview: per-row checkbox, per-row category, `Für alle` batch assign
- [ ] **Residual gap from 008:** the import button → `persist` wiring is the one step no automated test covers. Confirm the kept rows actually land in the account
- [ ] Re-importing the same file warns with the earlier import date (doc hash), and proceeding is possible
- [ ] Duplicate rows are marked on **both** copies within one batch

### Line-items (015, 019)
- [ ] Positions section appears in the booking form in edit mode only
- [ ] Drag handle reorders while the horizontal swipe still deletes (same shared-gesture risk as the category tree)
- [ ] Footer `Σ … von …` matches the booking total
- [ ] The Restposten row carries its chip, has no drag handle and refuses to swipe away
- [ ] Editing a position re-closes the gap: the Restposten updates or disappears without a manual reload
- [ ] `quantity × unitPrice ≠ amount` shows the inline warning but still saves

### Receipt scan (016, 017, 018)
- [ ] Camera path: `Kassenbon scannen` → Kamera opens **without** a permission prompt, capture returns to the flow
- [ ] Gallery path: picker opens (Photo Picker on API 33+), chosen image returns to the flow
- [ ] OCR umlauts: a real receipt round-trips `Käse`, `Öl`, `Süß`, `Brühe` in the review screen
- [ ] Rotation: a portrait capture is recognized as well as a landscape one — ML Kit reading EXIF through `InputImage.fromFilePath` is the assumption behind the temp-file detour
- [ ] Heuristic accuracy on ≥ 3 receipts from different shops: note how many rows land `ok` / `ambiguous` / `unparsed`, and whether two receipt rows were ever merged into one candidate
- [ ] Prices land on the right rows (rightmost-money-token rule against real column layout)
- [ ] Skip list catches each receipt's totals block; no `Summe` / `MwSt` row becomes a position
- [ ] Review screen: toggles, row edit, `Zeile hinzufügen`, `alle kategorisieren` behave on a real list
- [ ] Confirm persists with the right sign and the Restposten closes the gap
- [ ] Re-scanning the same photo triggers the doc-hash warning, and proceeding notes `Erneuter Scan trotz Warnung`
- [ ] `Weiteren Bon scannen` runs a second pass on the same booking
- [ ] Cache directory holds no `scan_*.jpg` leftovers after several passes (the `finally` delete fires on device)

### Monthly report (020)
- [ ] The donut paints at all — first `fl_chart` usage in the app, and no test has rendered a frame
- [ ] Slice percentage labels stay legible; the 8 % cut-off hides the ones that would not fit
- [ ] Filter bar survives a narrow screen: month row, account chip and the Ausgaben/Einnahmen toggle must not overflow
- [ ] Month picker opens in year mode and returns the picked month
- [ ] `Ohne Kategorie` row is visibly muted and stays out of the donut
- [ ] Drilldown shows `X (direkt)` first and its total equals the row that was tapped
- [ ] A category with many siblings still produces a readable donut (colour repetition from the 12-colour palette is expected — judge whether it is confusing)

### Forecast (021)
- [ ] The `LineChart` paints: history dots, thin fitted line, dashed projection continuing from the last measured month
- [ ] Axis labels stay readable at 3 months of history **and** at 12 + a 12-month horizon (24 x-labels in one axis is the crowding case)
- [ ] `Fenster` and `Horizont` chip rows do not overflow on a narrow screen
- [ ] Long-press on a report row opens the forecast — judge whether the gesture is discoverable enough without a visible affordance, since it is the primary path from report to forecast
- [ ] The app-bar `Prognose` action in the drilldown opens the same screen with the same numbers
- [ ] `Anpassungsgüte` reads plausibly against the visible scatter (a flat series must not claim 100 %)

### Item price trends (022)
- [ ] Search settles after the 300 ms debounce without flicker while typing
- [ ] Result rows read `<n> Käufe` with the latest unit price; a single purchase says `1 Kauf`
- [ ] Chart paints: one dot per purchase, min/max dashed marker lines, labels legible against the line
- [ ] The x-axis is a real time axis — an irregular gap between purchases must *look* irregular, and both end labels stay readable
- [ ] The y-axis does **not** start at zero: a 20-cent move on a ~1,50 € article has to be visible
- [ ] Everything bought on one day (zero span) still renders instead of collapsing the axis
- [ ] A never-changing price shows the single `Preis …` marker, not Min and Max stacked on each other
- [ ] Long-press on a position row opens that article's history; the Restposten row does not react
- [ ] `Nur ein Datenpunkt (…)` and `Keine Käufe erfasst` appear where expected
- [ ] Grouping against real OCR data: note how many spelling variants of one product became separate groups — that count decides whether the item-merge follow-up is worth a ticket

### Category suggestions (014)
- [ ] Leaving the counterparty field fills the category and the subtitle reads `Vorschlag · <n>×`, without the row overflowing on a narrow screen
- [ ] `Alternativen` opens the sheet with at most 3 entries and their counts; picking one replaces the category and drops the marker
- [ ] Picking a category by hand drops the marker too
- [ ] Import preview: suggested rows show the marker + count next to the chip without overflowing — the row already overflowed once (errors.md)
- [ ] Tapping the marker opens the alternatives while tapping the chip still opens the full tree
- [ ] Learn loop on real statements: accepting a suggestion must not raise its count, overriding must raise the new category's count until it wins
- [ ] A rule whose category was archived produces no suggestion

## Affected Tests
None — this ticket adds no automated test. Findings may add them through their own Bug tickets.

## Fixtures Needed
No — real statements and real receipts, both kept out of git.
