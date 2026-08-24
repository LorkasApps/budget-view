# Infrastructure (Infra domain)

Current state of the project foundation. Updated as Setup-epic tickets complete.

## Stack
| Concern | Choice |
|---------|--------|
| Framework | Flutter 3.44.x (Dart 3.12.x) |
| Platform target | Android only |
| State management | Riverpod (`flutter_riverpod` ^2.6.1) |
| Local persistence | `isar_community` 3.3.2 (+ `_flutter_libs`, `_generator`) — **no DB encryption** |
| Codegen | `build_runner` + `isar_community_generator` (`make gen`) |
| Linter | `flutter_lints` (default rules) |
| Charts | `fl_chart` ^1.2.0 |
| Device-local UI preferences | `shared_preferences` ^2.5.5 (theme mode only; not in Isar or `AppMeta`) |
| Package / applicationId | `de.lorkaps_apps.budget_view` |
| App display name | `BudgetView` (Android manifest `android:label`) |
| Theme seed | Teal `#009688` = `Colors.teal`, both `ColorScheme.fromSeed(seedColor: Colors.teal)` (light) and `.fromSeed(..., brightness: Brightness.dark)` (dark), Material 3 (`lib/main.dart`) |
| Launcher icon / splash | `flutter_launcher_icons` ^0.14.4, `flutter_native_splash` ^2.4.8 (dev-only) |
| Branding assets | SVG + PNG in `assets/icon/`: `money_bag.svg` (teal+white), `money_bag_foreground.svg` (white), `money_bag_monochrome.svg` (white) — all from one path; rasterised by `tool/svg_to_png.py` |

## Folder Layout (feature-first)
```
lib/
  main.dart              # ProviderScope + BudgetViewApp root
  app/                   # app-level composition root (AppShell, MenuScreen)
  core/                  # shared cross-feature code (persistence, sync, utils)
  features/
    <feature>/
      presentation/      # widgets, screens, controllers
      domain/            # entities-as-domain, services, repositories (interfaces)
      data/              # Isar collections, repository impls
```
Per-feature `{presentation,domain,data}` folders are created by each feature ticket, not upfront.

## Entry Point
`lib/main.dart` (async): `WidgetsFlutterBinding.ensureInitialized()` → `openAppIsar()` → `SharedPreferences.getInstance()` → `runApp(ProviderScope(overrides: [isarProvider.overrideWithValue(isar), preferenceStoreProvider.overrideWithValue(SharedPreferencesStore(preferences))], child: BudgetViewApp()))`. `BudgetViewApp` → `ConsumerWidget`, sets `MaterialApp.themeMode` to `themeModeProvider`, with `theme` and `darkTheme` both set → `AppShell` (`lib/app/app_shell.dart`): a `NavigationBar` with tabs `Konten` | `Report` | `Mehr` over an `IndexedStack` (`AccountListScreen`, `MonthlyCategoryReportScreen`, `MenuScreen`) wrapped in `PopScope<void>(canPop: _index == 0)` — back at a secondary tab selects `Konten`, back at `Konten` leaves the app. The `IndexedStack` keeps each tab's state across switches.

**Back gesture:** predictive back is on app-wide (`android:enableOnBackInvokedCallback="true"` on `<application>`). Pushed routes, sheets and dialogs are separate routes above the shell's, so the shell's `PopScope` is never consulted for them. Two non-obvious points: a `PopScope` that intercepts a pop suppresses the preview animation for exactly that gesture, so the tab root does not animate even with the flag on; and the type parameter is written out (`PopScope<void>`) because with an inferred one `find.byType(PopScope)` matches nothing in the widget test.

`MenuScreen` (`lib/app/menu_screen.dart`) and `SettingsScreen` (`lib/app/settings_screen.dart`) are app-level surfaces (collect features from multiple domains, so they belong to none). `MenuScreen` lists rare or contextual surfaces: each `ListTile` **pushes** a route, so back returns. A tab is earned by frequency, keeping the bar at three (decisions.md). Currently three tiles: `Prognose`, `Preistrends`, `Einstellungen` (settings icon, subtitle shows `Import-Historie und Tagging-Regeln`). `SettingsScreen` (reached via `Einstellungen`) carries configuration surfaces — three rows: `Erscheinungsbild` opens a dialog with three options in a `RadioGroup<ThemeMode>` (`Dunkel` | `Hell` | `Systemvorgabe`, the default) and applies the pick at once, while `Import-Historie` and `Tagging-Regeln` each push their screen (`ImportHistoryScreen`, `TaggingRulesScreen`).

## Persistence (`lib/core/persistence/`)
| File | Role |
|------|------|
| `app_meta.dart` | `AppMeta` singleton collection (id=0): `schemaVersion`, `installId` (UUID v4), `createdAt` |
| `schema_version.dart` | `kDbSchemaVersion` constant (currently `1`) |
| `isar_db.dart` | `appIsarSchemas` list + `openAppIsar({directory})` — opens Isar, seeds/reconciles `AppMeta` |
| `isar_provider.dart` | `isarProvider` (throws unless overridden with an open instance) |
| `dev_tools.dart` | `DevTools.wipeDatabase(isar)` — dev nuke (`close(deleteFromDisk: true)`) |

**Encryption:** none. Relies on Android file-based encryption + app-scoped storage (see decisions.md). Adding a collection = add its `Schema` to `appIsarSchemas` + run `make gen`.

**Schema versioning:** a bump is only *recorded* — `openAppIsar`'s reconcile writes the new `schemaVersion` into `AppMeta` and deletes nothing. Nuking is a deliberate `DevTools.wipeDatabase` call, wired to no UI. Additive changes need no wipe at all: Isar returns the field default for rows written before it existed (ticket 032 added `Transaction.kind` this way, and the existing bookings read back as `regular`). Prod (v1.0+) = migration steps in that reconcile, keyed on the stored version.

## Preferences (`lib/core/preferences/`)
| File | Role |
|------|------|
| `preference_store.dart` | `PreferenceStore` interface (`getString`, `setString`) + `SharedPreferencesStore` impl (reads synchronous over an already-obtained `SharedPreferences`). Interface exists because the plugin has no binding in the test VM; widget tests inject their own store. |
| `preference_store_provider.dart` | `preferenceStoreProvider` (throws unless overridden), same shape as `isarProvider`. |

The only consumer so far is `lib/app/theme_mode_controller.dart`: `themeModeProvider` (a `NotifierProvider`) with `ThemeModeController` — preference key `theme_mode`, stores `ThemeMode.name`, an absent or unknown value reads back as `ThemeMode.system`. It sits under `app/` because the theme belongs to the shell, not to the storage layer.

**Isolation:** device-local only. Never synced, never persisted to Isar, nothing about `AppMeta` or `kDbSchemaVersion`. `DevTools.wipeDatabase` does not clear preferences — the theme choice survives a dev nuke.

## Developer Commands
All Flutter commands run via the root `Makefile` (Flutter cannot run in the agent sandbox). Key targets: `make get`, `make check` (analyze+test), `make gen` (build_runner, from ticket 002), `make run`, `make build-apk`. Branding: `make icon-png` (SVG→PNG), `make icons` (`flutter_launcher_icons`), `make splash` (`flutter_native_splash`). `make help` lists all.

`make release-check` (= `check` + `build-apk`) is the gate before shipping: R8 runs for release only, so `make check` structurally cannot see shrinker breakage. Keep rules live in `android/app/proguard-rules.pro` (ML Kit ships Latin only — see errors.md).

**Warning:** both generators own committed Android res files (see ticket 027, Generator-owned files section). Hand edits are unsafe — regenerate instead.

## Setup epic complete
Foundation done (tickets 001–003): Flutter scaffold, Isar persistence, sync stub. Feature epics (Accounts onwards) build on this. See `sync.md` for the repository-layer contract every feature repo must follow.
