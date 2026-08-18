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
| Package / applicationId | `de.lorkaps_apps.budget_view` |
| App display name | `BudgetView` (Android manifest `android:label`) |

## Folder Layout (feature-first)
```
lib/
  main.dart              # ProviderScope + BudgetViewApp root
  app/                   # app-level composition root (AppShell)
  core/                  # shared cross-feature code (persistence, sync, utils)
  features/
    <feature>/
      presentation/      # widgets, screens, controllers
      domain/            # entities-as-domain, services, repositories (interfaces)
      data/              # Isar collections, repository impls
```
Per-feature `{presentation,domain,data}` folders are created by each feature ticket, not upfront.

## Entry Point
`lib/main.dart` (async): `WidgetsFlutterBinding.ensureInitialized()` → `openAppIsar()` → `runApp(ProviderScope(overrides: [isarProvider.overrideWithValue(isar)], child: BudgetViewApp()))`. `BudgetViewApp` → `MaterialApp` (Material 3, teal seed) → `AppShell` (`lib/app/app_shell.dart`): a `NavigationBar` with tabs `Konten` | `Report` over an `IndexedStack` (`AccountListScreen`, `MonthlyCategoryReportScreen`) — the `IndexedStack` is what keeps each tab's state across switches.

## Persistence (`lib/core/persistence/`)
| File | Role |
|------|------|
| `app_meta.dart` | `AppMeta` singleton collection (id=0): `schemaVersion`, `installId` (UUID v4), `createdAt` |
| `schema_version.dart` | `kDbSchemaVersion` constant (currently `1`) |
| `isar_db.dart` | `appIsarSchemas` list + `openAppIsar({directory})` — opens Isar, seeds/reconciles `AppMeta` |
| `isar_provider.dart` | `isarProvider` (throws unless overridden with an open instance) |
| `dev_tools.dart` | `DevTools.wipeDatabase(isar)` — dev nuke (`close(deleteFromDisk: true)`) |

**Encryption:** none. Relies on Android file-based encryption + app-scoped storage (see decisions.md). Adding a collection = add its `Schema` to `appIsarSchemas` + run `make gen`.

**Schema versioning:** dev = nuke+rebuild on bump (`DevTools.wipeDatabase`); prod (v1.0+) = migration steps in `openAppIsar`'s reconcile, keyed on stored `schemaVersion`.

## Developer Commands
All Flutter commands run via the root `Makefile` (Flutter cannot run in the agent sandbox). Key targets: `make get`, `make check` (analyze+test), `make gen` (build_runner, from ticket 002), `make run`, `make build-apk`. `make help` lists all.

## Setup epic complete
Foundation done (tickets 001–003): Flutter scaffold, Isar persistence, sync stub. Feature epics (Accounts onwards) build on this. See `sync.md` for the repository-layer contract every feature repo must follow.
