import 'package:isar_community/isar.dart';

import '../../../core/sync/syncable_entity.dart';
import 'imported_source_kind.dart';

part 'imported_source.g.dart';

/// Metadata of one completed import. The document itself is never stored, so
/// this row is all that remains — enough to warn on a re-import and to show an
/// import history.
///
/// [contentHashSha256] is deliberately **not** unique: overriding a re-import
/// warning creates a second row for the same file, and that history is the
/// point.
@collection
class ImportedSource implements SyncableEntity {
  Id id = Isar.autoIncrement;

  @override
  @Index(unique: true)
  String uuid = '';

  @enumerated
  late ImportedSourceKind kind;

  @Index()
  late String contentHashSha256;

  /// Display name from the picker; empty for camera captures.
  String filename = '';

  late DateTime importedAt;

  int transactionsProduced = 0;

  int lineItemsProduced = 0;

  /// Free text, e.g. that the user overrode a duplicate warning.
  String? note;

  late DateTime createdAt;

  late DateTime updatedAt;

  @override
  @ignore
  String get entityType => 'importedSource';

  @override
  Map<String, dynamic> toSyncPayload() => {
        'uuid': uuid,
        'kind': kind.name,
        'contentHashSha256': contentHashSha256,
        'filename': filename,
        'importedAt': importedAt.toIso8601String(),
        'transactionsProduced': transactionsProduced,
        'lineItemsProduced': lineItemsProduced,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
