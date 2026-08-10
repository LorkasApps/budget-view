# Supabase sync adapter (stub)

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Setup |
| **Domain** | Infra |
| **Blocked By** | 002 |
| **Status** | Ready |

## Description
Define the `SyncAdapter` abstraction so the domain layer never talks to a concrete sync backend. Ship a local-only concrete impl that captures every mutation as an Op-Log entry in an Isar collection. Actual Supabase wiring lands in a later ticket — this stub validates the design end-to-end without network.

## Architecture
- **Interface:** `SyncAdapter` with `enqueue(op, entity)` + `sync()` (async, returns success/failure).
- **Concrete impl for now:** `LocalSyncAdapter` — writes entries to `ChangeQueueEntry` Isar collection. `sync()` is a no-op that returns success + optionally marks entries as processed.
- **Hook point:** Repository layer. Every `save()` / `delete()` on a repository calls `adapter.enqueue(...)` in the same unit of work.
- **Entity identity:** every domain entity implements `SyncableEntity` and carries a `String uuid` (v4, client-generated on first save). Isar auto-inc `id` stays internal.

## Acceptance Criteria
- [ ] `SyncAdapter` abstract class defined in `lib/core/sync/sync_adapter.dart`
- [ ] `ChangeQueueEntry` Isar collection: `{id (auto-inc), op (enum: create|update|delete), entityType, entityUuid, payloadJson, ts, processed (bool, default false)}`
- [ ] `LocalSyncAdapter` concrete impl enqueues entries into `ChangeQueueEntry`
- [ ] `sync()` is a no-op that flips `processed=true` on all pending entries and returns success
- [ ] `SyncableEntity` mixin/interface defined: exposes `uuid` (String) and `entityType` (String)
- [ ] `uuid` auto-populated on first `save()` if empty (uses `uuid` package, v4)
- [ ] Repository-Layer pattern documented in a short section of `.claude/docs/dependencies.md` or a new `sync.md`
- [ ] Riverpod provider `syncAdapterProvider` exposes the adapter (overridable in tests)
- [ ] Unit tests: `enqueue(create)`, `enqueue(update)`, `enqueue(delete)`, `sync()` drains queue
- [ ] No network calls anywhere in the code

## Affected Tests
- `test/core/sync/local_sync_adapter_test.dart` — enqueue + drain
- `test/core/sync/syncable_entity_test.dart` — UUID auto-population

## Fixtures Needed
No — in-memory Isar for tests suffices.

## Notes
When the real Supabase impl arrives, it swaps `LocalSyncAdapter` for a `SupabaseSyncAdapter` that reads the queue + pushes to remote. Interface + queue schema should not need to change.

## Refinement Tokens (estimate)
- Input: ~7k tokens
- Output: ~2k tokens

## Token Usage
_Filled after Done._
