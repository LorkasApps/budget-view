# Supabase sync adapter (stub)

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Setup |
| **Domain** | Infra |
| **Blocked By** | 002 |
| **Status** | Done |

## Description
Define the `SyncAdapter` abstraction so the domain layer never talks to a concrete sync backend. Ship a local-only concrete impl that captures every mutation as an Op-Log entry in an Isar collection. Actual Supabase wiring lands in a later ticket — this stub validates the design end-to-end without network.

## Architecture
- **Interface:** `SyncAdapter` with `enqueue(op, entity)` + `sync()` (async, returns success/failure).
- **Concrete impl for now:** `LocalSyncAdapter` — writes entries to `ChangeQueueEntry` Isar collection. `sync()` is a no-op that returns success + optionally marks entries as processed.
- **Hook point:** Repository layer. Every `save()` / `delete()` on a repository calls `adapter.enqueue(...)` in the same unit of work.
- **Entity identity:** every domain entity implements `SyncableEntity` and carries a `String uuid` (v4, client-generated on first save). Isar auto-inc `id` stays internal.

## Acceptance Criteria
- [x] `SyncAdapter` interface defined in `lib/core/sync/sync_adapter.dart` (+ `SyncResult`)
- [x] `ChangeQueueEntry` Isar collection: `{id (auto-inc), op (@enumerated), entityType (indexed), entityUuid (indexed), payloadJson, ts, processed=false}`
- [x] `LocalSyncAdapter` concrete impl enqueues entries into `ChangeQueueEntry`
- [x] `sync()` is a no-op that flips `processed=true` on all pending entries and returns `SyncResult(processed: n)`
- [x] `SyncableEntity` interface defined: `uuid` (get/set), `entityType`, `toSyncPayload()`
- [x] `uuid` auto-populated via `ensureUuid()` extension (uuid v4) — repos call it on first save (from ticket 004)
- [x] Repository-Layer pattern documented in `.claude/docs/sync.md`
- [x] Riverpod provider `syncAdapterProvider` exposes the adapter (overridable in tests)
- [x] Unit tests: `enqueue(create/update/delete)`, `sync()` drains, empty-queue → 0, `ensureUuid` behavior
- [x] No network calls anywhere in the code

## Affected Tests
- `test/core/sync/local_sync_adapter_test.dart` — enqueue + drain + empty-queue + `ensureUuid` (UUID auto-population folded in here rather than a separate file)

## Fixtures Needed
No — in-memory Isar for tests suffices.

## Notes
When the real Supabase impl arrives, it swaps `LocalSyncAdapter` for a `SupabaseSyncAdapter` that reads the queue + pushes to remote. Interface + queue schema should not need to change.

## Refinement Tokens (estimate)
- Input: ~7k tokens
- Output: ~2k tokens

## Implementation Tokens (estimate)
- Input: ~14k tokens
- Output: ~3.5k tokens
