import 'package:isar_community/isar.dart';

import '../../../core/sync/syncable_entity.dart';

part 'tagging_rule.g.dart';

/// Which transaction field a rule matches on. Only [counterparty] is learned
/// today; the enum leaves room for description-based rules without a migration.
enum TaggingMatchField { counterparty, description }

/// One learned mapping from a normalized counterparty to a category.
///
/// [hitCount] is the confidence signal: re-assigning the same counterparty to
/// the same category raises it, and ticket 014 suggests the strongest rule.
/// Rules are never soft-deleted — see the repository.
@collection
class TaggingRule implements SyncableEntity {
  Id id = Isar.autoIncrement;

  @override
  @Index(unique: true)
  String uuid = '';

  /// Unique per (value, field, category): one counterparty may legitimately
  /// have rules for several categories, each with its own history.
  @Index(
    unique: true,
    composite: [CompositeIndex('matchField'), CompositeIndex('categoryUuid')],
  )
  late String matchValueNorm;

  @Enumerated(EnumType.name)
  TaggingMatchField matchField = TaggingMatchField.counterparty;

  late String categoryUuid;

  int hitCount = 1;

  late DateTime lastAssignedAt;

  late DateTime createdAt;

  late DateTime updatedAt;

  @override
  @ignore
  String get entityType => 'taggingRule';

  @override
  Map<String, dynamic> toSyncPayload() => {
        'uuid': uuid,
        'matchField': matchField.name,
        'matchValueNorm': matchValueNorm,
        'categoryUuid': categoryUuid,
        'hitCount': hitCount,
        'lastAssignedAt': lastAssignedAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
