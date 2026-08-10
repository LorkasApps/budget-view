import 'dart:convert';

import 'package:isar_community/isar.dart';

import 'change_queue_entry.dart';
import 'sync_adapter.dart';
import 'sync_op.dart';
import 'syncable_entity.dart';

/// Local-only [SyncAdapter]: writes every mutation to the [ChangeQueueEntry]
/// collection. [sync] is a no-op that marks pending entries processed — no
/// network. Swapped for a real backend adapter in a later ticket; the
/// interface + queue schema should not need to change.
class LocalSyncAdapter implements SyncAdapter {
  LocalSyncAdapter(this._isar);

  final Isar _isar;

  @override
  Future<void> enqueue(SyncOp op, SyncableEntity entity) async {
    final entry = ChangeQueueEntry()
      ..op = op
      ..entityType = entity.entityType
      ..entityUuid = entity.uuid
      ..payloadJson = jsonEncode(entity.toSyncPayload())
      ..ts = DateTime.now()
      ..processed = false;

    await _isar.writeTxn(() async {
      await _isar.changeQueueEntrys.put(entry);
    });
  }

  @override
  Future<SyncResult> sync() async {
    final pending =
        await _isar.changeQueueEntrys.filter().processedEqualTo(false).findAll();

    await _isar.writeTxn(() async {
      for (final entry in pending) {
        await _isar.changeQueueEntrys.put(entry..processed = true);
      }
    });

    return SyncResult(processed: pending.length);
  }
}
