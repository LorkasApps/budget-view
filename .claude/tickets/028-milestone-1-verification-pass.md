# Verification pass for milestone 1 (device + visual)

| Field | Value |
|-------|-------|
| **Type** | TechDebt |
| **Epic** | None |
| **Domain** | Infra |
| **Blocked By** | 024, 025, 026 |
| **Severity** | Medium |
| **Effort** | XL |
| **Status** | In Progress |

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

## Resolved during refinement
- **Sequencing** → blocked on 024, 025, 026 and run as **one** pass once they land, so the new Settings surface, the rule
  list and the picker quick-create are walked in the same sitting. Accepted cost: the base stays unverified until then,
  and a defect in it is found only after three features have been built on top
- **Test data** → real statements and real receipts only. A check whose data does not exist yet (12 months of history for
  the forecast axis, repeated purchases of one article) is **not** ticked but marked `vertagt: braucht <N> Monate Daten`.
  No seed generator: this ticket produces findings, not code
- **Definition of Done** → every check is either ticked, turned into its own Bug ticket, or explicitly deferred. Whether
  the resulting bugs are fixed is their own lifecycle. `Done` here means "the pass happened", not "the app is fine" —
  otherwise a low-severity cosmetic bug would hold the whole milestone open
- **Findings** → noted inline behind the check, but only when there is something to note: a deviation (with its Bug
  ticket id), a deferral, or a number the check explicitly asks for (OCR hit rate, how many spelling variants became
  separate groups). A clean pass stays a bare tick

## Verification Strategy
One pass on a physical Android device, `make run` (since ticket 030 a release APK also builds, so `make build-apk` +
`make install-apk` works if you would rather walk it off the cable).

Light mode only: the theme-mode setting is ticket 031 and is not built yet, so its dark-mode checks — including whether
the category palette and the chart colours hold up — belong to that ticket, not this pass. Note the observation next to
each item; deviations become Bug tickets. Work area by area — the order below
follows the app's own flow, so the data each later area needs already exists.

## Acceptance Criteria

### Boot + shell (001–003, 020, 021)
- [x] Cold start opens the account list, no crash while Isar opens
- [x] Bottom nav switches `Konten` / `Report` / `Mehr` (029 moved the rare surfaces behind the menu); each tab keeps its scroll position and filter state across switches (that is what the `IndexedStack` is for)
- [x] `Mehr` lists `Prognose`, `Preistrends` and `Einstellungen` (024 added the third), and back returns to the menu rather than to a tab
- [x] German umlauts render correctly in every screen title and label
- [x] Amounts read as `1.234,56 €` throughout (`de_DE`, non-breaking space before the symbol)
- [x] Launcher icon + splash (027) — verified 2026-08-20 on device: icon at grid size, startup shows the mark, themed
      variant renders. No deviation

### Accounts (004, 005)
- [x] List renders, total header sums the accounts, per-account balance matches opening balance + bookings
- [x] A negative balance is visibly in the error colour, not just differently signed
- [x] Swipe → archive asks first; long-press on an archived row restores it
- [x] Form: name validation, type dropdown, EUR input accepting `,` and `.`, date picker refusing the future.
      Note: two validator messages are unreachable through the UI — the amount field opens a number pad, so
      `Ungültiger Betrag` needs a paste to fire, and the date picker does not offer future dates at all, so
      `Datum darf nicht in der Zukunft liegen` never shows. Both validators stay unit-tested; whether the guards
      earn their place is a judgement call, not a defect

### Transactions (006, 011)
- [x] List is newest-first with the saldo header; swipe → delete confirms
- [x] Row `CategoryChip` quick-pick reassigns inline and the row updates immediately
- [x] Form: Ausgabe/Einnahme toggle drives the sign, missing category shows `Kategorie erforderlich` in red
- [ ] Uncategorized-only filter in the app bar actually narrows the list — **deferred to after the PDF import area**:
      manual entry forces a category, so an uncategorized row only exists once an import produced one. Filtering from
      "everything" to "nothing" would not have proven the predicate

### Categories (010, 012)
- [x] Tree expands/collapses; the drag handle reorders siblings **without** stealing the long-press that archives (the two gestures share one row — this is the point of the explicit `ReorderableDragStartListener`)
- [x] Reorder across levels is refused with the snackbar, not silently applied
- [x] Icon grid (24) and colour grid (12) both render and persist the choice
- [x] Deleting a category that has children or bookings shows the German block message with the right counts
- [x] Picker sheet: `Erbt von der Buchung (…)` label appears for line-items, `Keine Kategorie` where allowed.
      Checked with a categorized booking (real category name in the label) and in the booking form (no none-row at
      all). The `Erbt von der Buchung (ohne Kategorie)` wording needs a booking without a category, which manual
      entry cannot produce — **deferred to after the PDF import area**

### PDF import (007, 008, 009)
- [x] `file_selector` opens and returns a real ING statement
- [x] The statement parses: row count and amounts match the paper, `Neuer Saldo − Alter Saldo` reconciles
- [x] A statement from a **second** layout / another bank is either parsed or rejected with a readable message — never
      silently half-parsed. Foreign statement ranks `ing-giro-v1` at 0 % and the screen asks whether this really is an
      ING statement, so the user gets a decision rather than a wrong import
- [x] Preview: per-row checkbox, per-row category, `Für alle` batch assign
- [x] **Residual gap from 008:** the import button → `persist` wiring is the one step no automated test covers. Confirm the kept rows actually land in the account
- [x] Re-importing the same file warns with the earlier import date (doc hash), and proceeding is possible
- [x] Duplicate rows are marked on **both** copies within one batch

### Line-items (015, 019)
- [x] Positions section appears in the booking form in edit mode only
- [x] Drag handle reorders while the horizontal swipe still deletes (same shared-gesture risk as the category tree)
- [x] Footer `Σ … von …` matches the booking total
- [x] The Restposten row carries its chip, has no drag handle and refuses to swipe away. Note: the row showed up only
      after a save when no Restposten existed before. Whether that was the position save (the documented reconciler
      call site, so as designed) or only the booking save (which would mean the sheet skips reconcile for the *first*
      position) was not distinguished — user judged the behaviour acceptable, so it stays a note rather than a ticket
- [x] Editing a position re-closes the gap: the Restposten updates or disappears without a manual reload
- [x] `quantity × unitPrice ≠ amount` shows the inline warning but still saves

### Receipt scan (016, 017, 018) — moved to ticket 036
- [x] Camera path: `Kassenbon scannen` → Kamera opens **without** a permission prompt, capture returns to the flow
      (debug build; the release APK fails the recognition outright — ticket **034**)
- [x] Gallery path: picker opens (Photo Picker on API 33+), chosen image returns to the flow
- [x] Two checks failed outright and became tickets **034** (release build recognises nothing) and **035** (skew pairs
      prices with the neighbouring item; address, total, `Bargeld`, `Rückgeld` and EC rows arrive as positions)
- [x] The remaining receipt checks moved to ticket **036** together with the PDF-receipt checks of 033: running them
      against a pipeline this broken would have measured the known defects instead of their own subject

### Monthly report (020)
_Finding from this pass (not a check): `Ausgaben` read 12.891,34 for July against a real spend of roughly 3k. The sums are
correct — net −467,36 reconciles with `Neuer Saldo − Alter Saldo` — but transfers to another own account count as
spending, because a booking knows only amount and sign. Ticket **032**._
- [x] The donut paints at all — first `fl_chart` usage in the app, and no test has rendered a frame
- [x] Slice percentage labels stay legible; the 8 % cut-off hides the ones that would not fit — a 1 % slice renders
      without its label, as intended
- [x] Filter bar survives a narrow screen: month row, account chip and the Ausgaben/Einnahmen toggle must not overflow
- [x] Month picker opens in year mode and returns the picked month. The **result** is right (picking 05.06 yields June),
      but after the year sheet comes a day grid rather than a month overview. Accepted as-is: Flutter's `DatePickerMode`
      has only `day` and `year`, so a month-granular dialog would have to be hand-built including its accessibility
      behaviour — more risk than the misleading day precision is worth (decisions.md)
- [x] `Ohne Kategorie` row is visibly muted and stays out of the donut
- [x] Drilldown shows `X (direkt)` first and its total equals the row that was tapped
- [x] A category with many siblings still produces a readable donut (colour repetition from the 12-colour palette is
      expected — judge whether it is confusing). Judged at 5 children; a larger tree has not been tried

### Forecast (021)
- [x] The `LineChart` paints: history dots, thin fitted line, dashed projection continuing from the last measured month
- [x] Axis labels stay readable at 3 months of history **and** at 12 + a 12-month horizon (24 x-labels in one axis is
      the crowding case) — short-history half only. The crowding case is **vertagt: braucht 12 Monate Daten**
- [x] `Fenster` and `Horizont` chip rows do not overflow on a narrow screen
- [x] Long-press on a report row opens the forecast — judge whether the gesture is discoverable enough without a
      visible affordance, since it is the primary path from report to forecast. Found only after being told where to
      press: the first attempt went to the trend screen. `(direkt)` and `Ohne Kategorie` correctly do not react
- [x] The app-bar `Prognose` action in the drilldown opens the same screen with the same numbers
- [x] `Anpassungsgüte` reads plausibly against the visible scatter (a flat series must not claim 100 %)

### Item price trends (022)
_Verified with hand-entered positions (same article across four bookings): real OCR data is
not trustworthy while 035 is open._
- [x] Search settles after the 300 ms debounce without flicker while typing
- [x] Result rows read `<n> Käufe` with the latest unit price; a single purchase says `1 Kauf`
- [x] Chart paints: one dot per purchase, min/max dashed marker lines, labels legible against the line
- [x] The x-axis is a real time axis — an irregular gap between purchases must *look* irregular, and both end labels stay readable
- [x] The y-axis does **not** start at zero: a 20-cent move on a ~1,50 € article has to be visible
- [x] Everything bought on one day (zero span) still renders instead of collapsing the axis
- [x] A never-changing price shows the single `Preis …` marker, not Min and Max stacked on each other
- [x] Long-press on a position row opens that article's history; the Restposten row does not react
- [x] `Nur ein Datenpunkt (…)` and `Keine Käufe erfasst` appear where expected
- [x] Grouping against real OCR data — **moved to ticket 036**: the count only means something once 035 is fixed,
      since shifted prices and noise rows distort exactly the grouping it would measure

### Category suggestions (014)
- [x] Leaving the counterparty field fills the category and the subtitle reads `Vorschlag · <n>×`, without the row
      overflowing on a narrow screen. Suggestions also land on rows where they are wrong, which is the learn loop
      working as designed; the missing correction path in the import preview became ticket **037**
- [ ] `Alternativen` opens the sheet with at most 3 entries and their counts; picking one replaces the category and drops the marker
- [ ] Picking a category by hand drops the marker too
- [ ] Import preview: suggested rows show the marker + count next to the chip without overflowing — the row already overflowed once (errors.md)
- [ ] Tapping the marker opens the alternatives while tapping the chip still opens the full tree
- [ ] Learn loop on real statements: accepting a suggestion must not raise its count, overriding must raise the new category's count until it wins
- [ ] A rule whose category was archived produces no suggestion

### Settings, rules, quick-create (024, 025, 026)
- [ ] `Mehr` → `Einstellungen` opens; every row pushes its screen and back returns to `Einstellungen`, not to `Mehr`
- [ ] Import history: source label right for a PDF row and for a photo row, counts plausible, empty state on a fresh
      install. Delete is a **swipe** end-to-start with no visible affordance — judge whether it is discoverable, since
      it is the only action on the screen, and confirm the dialog says the bookings stay
- [ ] Rule list: the three sorts reorder (sort lives behind an app-bar icon — judge discoverability), remap keeps
      `hitCount`, an archived category marks its rules stale, the collective delete names the count and removes only
      those rows. Delete per rule is again a swipe
- [ ] Picker quick-create: the trailing `+` creates under the intended parent and never selects the row by accident —
      thumb-sized taps on a dense tree are exactly what a widget test cannot judge, a
      duplicate sibling name is refused inside the dialog, and on success the caller is left with the new category
      selected — walked from all four call sites

## Affected Tests
None — this ticket adds no automated test. Findings may add them through their own Bug tickets.

## Fixtures Needed
No — real statements and real receipts, both kept out of git.

### Refinement Tokens (estimate)
- Input: ~22k tokens
- Output: ~3k tokens

### Implementation Tokens (estimate)
_Filled after Done._
