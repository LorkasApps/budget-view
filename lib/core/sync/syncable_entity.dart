import 'package:uuid/uuid.dart';

const _uuidGen = Uuid();

/// Contract for any domain entity that participates in sync.
///
/// Concrete Isar collections implement this from ticket 004 onwards. The
/// [uuid] is the cross-device business key; [entityType] tags the change-queue
/// row; [toSyncPayload] is the serialized snapshot pushed on a real sync.
abstract interface class SyncableEntity {
  String get uuid;
  set uuid(String value);

  /// Stable type tag, e.g. `account`, `transaction`. Constant per class.
  String get entityType;

  /// Serialized state for the change-queue payload.
  Map<String, dynamic> toSyncPayload();
}

extension SyncableEntityUuid on SyncableEntity {
  /// Assigns a fresh UUID v4 if none is set yet. Repositories call this on
  /// first save.
  void ensureUuid() {
    if (uuid.isEmpty) {
      uuid = _uuidGen.v4();
    }
  }
}
