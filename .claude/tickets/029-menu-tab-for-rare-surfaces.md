# Menu tab instead of one tab per surface

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | None |
| **Domain** | Infra |
| **Blocked By** | None |
| **Status** | Done |

## Description
The shell (built in 020, extended in 021) currently spends one bottom-nav
destination per surface. Three more low-frequency surfaces are planned — 022
(item price trends), 024 (import history), 025 (tagging-rule management) — which
would push the bar to six destinations, past the 3–5 Material 3 allows.

A destination earns a tab by **frequency**, not by existence. Daily paths stay in
the bar; everything rare, or reached from context anyway, moves behind a menu.

Final shape:

| Tab | Content | Why |
|-----|---------|-----|
| Konten | account list → bookings | daily, the entry path for data |
| Report | monthly category report | the app's main purpose |
| Mehr | list of the rare surfaces | grows without the bar growing |

`Prognose` moves into the menu: its natural path is already the long-press deep
link from a report row (021), so a permanent tab buys little.

Doing this **before** 022 avoids moving a screen, its tests and its docs twice.

## Acceptance Criteria
- [x] `AppShell` destinations become `Konten` | `Report` | `Mehr` (`Icons.more_horiz` / `more_horiz` selected), still over an `IndexedStack` so each tab keeps its scroll and filter state
- [x] New `MenuScreen` in `lib/app/menu_screen.dart` — app-level like the shell, not inside a feature: it links across domains and must not own any of them
- [x] Menu is a plain `ListView` of `ListTile`s (leading icon, title, subtitle, chevron). Adding a future surface = one tile, no shell change
- [x] First tile: `Prognose` → pushes `ForecastScreen()` as a route, so the back button returns to the menu rather than to a tab
- [x] `ForecastScreen` is no longer a shell tab. Its two existing entry points stay untouched: long-press on a report row and the `Prognose` app-bar action in the drilldown (both via `ReportLevelView.openForecast`)
- [x] Menu tiles carry a one-line subtitle each, so a rarely visited surface explains itself (`Prognose` → `Lineare Hochrechnung je Kategorie`)

## Affected Tests
- `test/app/app_shell_test.dart` — updated: three destinations, `Mehr` selects index 2, all three tabs stay mounted
- `test/app/menu_screen_test.dart` — new: tile list renders, tapping `Prognose` pushes `ForecastScreen`
- `test/features/analytics/presentation/forecast_screen_test.dart` — unchanged; the screen itself does not care how it was reached

## Fixtures Needed
No.

### Refinement Tokens (estimate)
- Input: ~14k tokens
- Output: ~2k tokens

Refined in the same round that produced the ticket: the frequency rule, the
three-tab shape, the menu screen's location and the forecast's move were all
settled there, so no question remained open at `Ready`.

### Implementation Tokens (estimate)
- Input: ~28k tokens
- Output: ~5k tokens

## Docs to update
- `.claude/docs/infrastructure.md` — entry point: three tabs plus the menu screen
- `.claude/docs/analytics.md` — the forecast's entry points: menu tile instead of shell tab
- `.claude/docs/decisions.md` — a tab is earned by frequency; rare surfaces go behind the menu
