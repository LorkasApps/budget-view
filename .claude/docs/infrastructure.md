# Infrastructure (Infra domain)

Current state of the project foundation. Updated as Setup-epic tickets complete.

## Stack
| Concern | Choice |
|---------|--------|
| Framework | Flutter 3.44.x (Dart 3.12.x) |
| Platform target | Android only |
| State management | Riverpod (`flutter_riverpod` ^2.6.1) |
| Linter | `flutter_lints` (default rules) |
| Package / applicationId | `de.lorkaps_apps.budget_view` |
| App display name | `BudgetView` (Android manifest `android:label`) |

## Folder Layout (feature-first)
```
lib/
  main.dart              # ProviderScope + BudgetViewApp root
  core/                  # shared cross-feature code (persistence, sync, utils)
  features/
    <feature>/
      presentation/      # widgets, screens, controllers
      domain/            # entities-as-domain, services, repositories (interfaces)
      data/              # Isar collections, repository impls
```
Per-feature `{presentation,domain,data}` folders are created by each feature ticket, not upfront.

## Entry Point
`lib/main.dart`: `runApp(ProviderScope(child: BudgetViewApp()))`. `BudgetViewApp` → `MaterialApp` (Material 3, teal seed) → `HomeScreen` placeholder.

## Developer Commands
All Flutter commands run via the root `Makefile` (Flutter cannot run in the agent sandbox). Key targets: `make get`, `make check` (analyze+test), `make gen` (build_runner, from ticket 002), `make run`, `make build-apk`. `make help` lists all.

## Not Yet Present (later Setup tickets)
- Isar persistence + encryption (ticket 002)
- Sync adapter + change-queue (ticket 003)
