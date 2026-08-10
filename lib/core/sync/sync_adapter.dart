import 'sync_op.dart';
import 'syncable_entity.dart';

/// Outcome of a [SyncAdapter.sync] run.
class SyncResult {
  const SyncResult({required this.processed});

  /// Number of change-queue entries drained in this run.
  final int processed;
}

/// Abstraction over the sync backend. The domain layer only ever talks to
/// this — never to a concrete backend. The stub impl ([LocalSyncAdapter])
/// captures changes locally; a future `SupabaseSyncAdapter` will push them.
abstract interface class SyncAdapter {
  /// Records a mutation for [entity] in the change queue.
  Future<void> enqueue(SyncOp op, SyncableEntity entity);

  /// Drains pending change-queue entries. Stub: no network, marks processed.
  Future<SyncResult> sync();
}
