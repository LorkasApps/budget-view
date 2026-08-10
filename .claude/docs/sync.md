# Sync (Infra)

Local-first change capture, prepared for a future Supabase backend. No network today.

## Components (`lib/core/sync/`)
| File | Role |
|------|------|
| `sync_op.dart` | `enum SyncOp { create, update, delete }` |
| `syncable_entity.dart` | `SyncableEntity` interface (`uuid`, `entityType`, `toSyncPayload()`) + `ensureUuid()` extension |
| `change_queue_entry.dart` | `ChangeQueueEntry` Isar collection (op-log row) |
| `sync_adapter.dart` | `SyncAdapter` interface + `SyncResult` |
| `local_sync_adapter.dart` | `LocalSyncAdapter` — enqueues to Isar; `sync()` marks entries processed |
| `sync_provider.dart` | `syncAdapterProvider` (Riverpod) → `LocalSyncAdapter(isar)` |

## ChangeQueueEntry schema
`{ id (auto), op (enum), entityType, entityUuid, payloadJson, ts, processed=false }`. Indexed on `entityType` + `entityUuid`.

## Repository-Layer contract (applies from ticket 004 onwards)
Every repository that persists a `SyncableEntity` MUST, within the same logical operation:
1. `entity.ensureUuid()` before first insert.
2. Write to its own Isar collection.
3. Call `syncAdapter.enqueue(op, entity)` with the matching `SyncOp`:
   - insert → `SyncOp.create`
   - update → `SyncOp.update`
   - soft-delete / delete → `SyncOp.delete`

There is no app-wide interceptor — enqueue is an explicit call in each repo. This keeps the sync boundary visible and testable.

## Entity requirements
A collection joining sync implements `SyncableEntity`: expose a stored `String uuid`, a constant `entityType`, and `toSyncPayload()` returning the JSON-able snapshot. `entityType` getter should be `@ignore`d for Isar (computed, not stored).

## Future (real backend)
Swap `LocalSyncAdapter` for `SupabaseSyncAdapter` in `sync_provider.dart`. It reads pending `ChangeQueueEntry` rows and pushes them; interface + queue schema stay the same. Conflict resolution + pull-side are separate future tickets.
