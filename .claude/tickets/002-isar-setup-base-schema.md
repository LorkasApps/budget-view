# Isar setup + base schema

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Setup |
| **Domain** | Infra |
| **Blocked By** | 001 |
| **Status** | Done |

## Description
Add `isar_community` 3.3.2 as local persistence layer. **No DB-level encryption** (Isar doesn't provide it; relying on Android file-based encryption + app-scoped storage — see decisions.md). Open the DB on app start at `getApplicationDocumentsDirectory()`, expose it via a Riverpod provider, set up code generation (`isar_community_generator` + `build_runner`), and establish the schema-versioning strategy (dev: nuke+rebuild, prod: manual from v1.0). Ships one base collection (`AppMeta`) so codegen has a target and the schema version has a home.

## Dependencies (pubspec)
```yaml
dependencies:
  isar_community: ^3.3.2
  isar_community_flutter_libs: ^3.3.2
  path_provider: ^2.1.4

dev_dependencies:
  isar_community_generator: ^3.3.2
  build_runner: ^2.4.13
```

## Base Collection — `AppMeta` (singleton row)

| Field | Type | Notes |
|-------|------|-------|
| `id` | Id | Fixed to `0` (single-row singleton) |
| `schemaVersion` | int | Mirrors `kDbSchemaVersion`; used to detect version bumps |
| `installId` | String | UUID v4 generated on first launch (useful later for sync) |
| `createdAt` | DateTime | First launch time |

## Acceptance Criteria
- [x] `isar_community` + `isar_community_flutter_libs` + `path_provider` added to `pubspec.yaml` (also `uuid`)
- [x] `isar_community_generator` + `build_runner` added to `dev_dependencies`
- [x] `make gen` (build_runner) succeeds and produces `app_meta.g.dart` (2 outputs; generator emitted non-fatal warnings)
- [x] `AppMeta` Isar collection defined in `lib/core/persistence/app_meta.dart`
- [x] `kDbSchemaVersion` constant = `1` in `lib/core/persistence/schema_version.dart`
- [x] DB opens on app start at `getApplicationDocumentsDirectory()` with the `AppMeta` schema (plain, no `encryptionKey`)
- [x] On first launch: `AppMeta` row created with `schemaVersion = kDbSchemaVersion`, fresh `installId` (UUID v4), `createdAt = now` (verified by test)
- [x] On later launches: stored `schemaVersion != kDbSchemaVersion` → reconciled up to current (verified by test); dev nuke via `DevTools.wipeDatabase`, prod migration = documented TODO for v1.0
- [x] Isar instance exposed via Riverpod provider (`isarProvider`) — async `openAppIsar()` resolved before `runApp`, injected via `ProviderScope.overrides`
- [x] Dev-mode reset helper `DevTools.wipeDatabase()` (`isar.close(deleteFromDisk: true)`)
- [x] Migration policy documented inline (dev nuke, prod manual from v1.0)
- [x] Smoke test: open temp-dir Isar, write + read back `AppMeta`, reopen keeps data, close cleanly
- [x] `make check` green (analyze + tests)

## Removed from earlier draft (encryption dropped)
- ~~`flutter_secure_storage` / Android Keystore key~~ — no longer needed
- ~~encrypted `Isar.open`~~ — Isar has no encryption

## Affected Tests
- `test/core/persistence/isar_open_test.dart` — open temp Isar, `AppMeta` round-trip, reopen keeps data
- `test/core/persistence/schema_version_test.dart` — first-launch seeds AppMeta; version-mismatch path invoked

## Fixtures Needed
No.

## Refinement Tokens (estimate)
- Input: ~6k tokens
- Output: ~1.5k tokens

## Re-refinement note (2026-08-10)
Reworked mid-implementation: `isar_community` has no 4.x (latest 3.3.2) and no built-in encryption. Encryption dropped per user decision; version corrected to 3.3.2.

## Implementation Tokens (estimate)
- Input: ~18k tokens
- Output: ~4k tokens
