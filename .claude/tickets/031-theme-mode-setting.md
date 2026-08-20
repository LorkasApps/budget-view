# Theme mode setting (dark / light / system)

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Setup |
| **Domain** | Infra |
| **Blocked By** | None (024 built the Settings surface) |
| **Status** | Ready |

## Description
`BudgetViewApp` hands `MaterialApp` a single light theme built from the teal seed, so the app stays bright whatever the
phone does. Wanted: a theme-mode choice on the Settings screen with three options, defaulting to the OS setting.

Given with the request, so not up for refinement:

| Option | Meaning |
|--------|---------|
| `Dunkel` | force dark |
| `Hell` | force light |
| `Systemvorgabe` | follow the OS — **our default** |

That maps onto `ThemeMode.dark` / `.light` / `.system`, which `MaterialApp.themeMode` already understands. The work is
the dark `ColorScheme` from the same seed, a place to keep the choice, and the row on the Settings screen.

## Acceptance Criteria
- [ ] Settings screen carries a theme-mode row with exactly three options: `Dunkel`, `Hell`, `Systemvorgabe`
- [ ] `Systemvorgabe` is the default on a fresh install, and switching the OS between light and dark flips the app while
      it runs
- [ ] `MaterialApp` gets a `darkTheme` from the **same** teal seed (`ColorScheme.fromSeed(seedColor: Colors.teal,
      brightness: Brightness.dark)`) — no second palette, same rule as ticket 027
- [ ] The choice survives an app restart
- [ ] Choosing an option applies it immediately, without reopening the screen
- [ ] Nothing else about the Settings screen changes
- [ ] The preference is read once at startup and written on change through `shared_preferences`; nothing about `AppMeta`,
      `kDbSchemaVersion` or any Isar collection is touched
- [ ] The widget test injects a fake preference store rather than the real plugin, which has no test-VM binding
- [ ] `make check` green

## Resolved during refinement
- **Storage** → `shared_preferences`, loaded in the existing async bootstrap in `main.dart` and handed in through a
  provider override, the same shape as `openAppIsar`. The choice is device-local and has nothing to do with the data
  model, so this avoids a schema bump and the sync question never arises — the alternative, an Isar collection, would
  have forced either syncing a device-local preference (wrong the moment a second device exists) or deliberately breaking
  the `SyncableEntity` contract every other entity keeps. `AppMeta` was rejected as well: it carries identity
  (`schemaVersion`, `installId`, `createdAt`), and a UI preference beside a schema version blurs what that row is for.
  The App-Lock toggle named in `decisions.md` inherits this home. Accepted cost: one dependency, and
  `DevTools.wipeDatabase` does not clear it — the theme choice survives a dev nuke

## Deposited for the 028 device pass
- The 12-colour `categoryPalette` and the `#607D8B` default were picked against a light background. Whether they stay
  legible in dark mode is a visual judgement, not something a test can assert — the pass should look at the donut, the
  tree and the chips in dark mode
- Both charts (`fl_chart` donut, forecast + price-trend line charts) draw with explicit colours in places; dark mode is
  where that shows

## Out of Scope
- Any theming beyond the seed-derived light and dark schemes — no custom dark palette, no per-surface overrides
- Category colours themselves (they are user data; a dark-mode contrast fix would be its own ticket)

## Affected Tests
- Widget test that the three options render, that picking one drives `MaterialApp.themeMode`, and that the default is
  `ThemeMode.system`

## Fixtures Needed
No. The test needs a theme-mode value and a fake store, no data setup at all — same call as 024, 025 and 026.

### Refinement Tokens (estimate)
- Input: ~12k tokens
- Output: ~2k tokens

### Implementation Tokens (estimate)
_Filled after Done._
