import 'package:isar_community/isar.dart';

import '../../../core/sync/syncable_entity.dart';

part 'category.g.dart';

/// A node in the user's free category tree.
///
/// [parentUuid] is null for a root. Absence is modelled as null rather than an
/// empty-string sentinel so that "not set" reads the same way here as it does
/// on `Transaction.categoryUuid`.
///
/// Direction (income vs expense) is never derived from where a category sits —
/// that comes from the sign of the transaction amount.
@collection
class Category implements SyncableEntity {
  Id id = Isar.autoIncrement;

  @override
  @Index(unique: true)
  String uuid = '';

  late String name;

  @Index()
  String? parentUuid;

  /// Manual sibling order. Defaults leave gaps so a single insert does not
  /// renumber the whole level.
  int sortOrder = 1000;

  String iconName = 'label';

  String colorHex = '#607D8B';

  bool archived = false;

  late DateTime createdAt;

  late DateTime updatedAt;

  @override
  @ignore
  String get entityType => 'category';

  @ignore
  bool get isRoot => parentUuid == null;

  @override
  Map<String, dynamic> toSyncPayload() => {
        'uuid': uuid,
        'name': name,
        'parentUuid': parentUuid,
        'sortOrder': sortOrder,
        'iconName': iconName,
        'colorHex': colorHex,
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
