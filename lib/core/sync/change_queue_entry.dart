import 'package:isar_community/isar.dart';

import 'sync_op.dart';

part 'change_queue_entry.g.dart';

/// One captured mutation, awaiting sync to a remote backend (Supabase, later).
///
/// Op-log style: op + entity identity + a JSON snapshot + timestamp.
@collection
class ChangeQueueEntry {
  Id id = Isar.autoIncrement;

  @enumerated
  late SyncOp op;

  @Index()
  late String entityType;

  @Index()
  late String entityUuid;

  late String payloadJson;

  late DateTime ts;

  bool processed = false;
}
