import 'package:isar_community/isar.dart';

import '../../../core/sync/syncable_entity.dart';

part 'transaction.g.dart';

/// A bank transaction. [amountCents] is signed: negative = expense,
/// positive = income. Soft-deleted via [deleted].
@collection
class Transaction implements SyncableEntity {
  Id id = Isar.autoIncrement;

  @override
  @Index(unique: true)
  String uuid = '';

  @Index()
  late String accountUuid;

  /// Null while uncategorized. Manual entry requires one, PDF import does not —
  /// that rule lives in the forms, not here.
  @Index()
  String? categoryUuid;

  late int amountCents;

  late DateTime bookingDate;

  late String description;

  String counterparty = '';

  String note = '';

  /// SHA-256 of amount + booking day + normalised counterparty. Maintained by
  /// the repository on every write; see `domain/dedupe_hash.dart`.
  @Index()
  String dedupeHash = '';

  /// True while the category came from an accepted auto-suggestion (ticket 014)
  /// rather than the user. The tagging learn hook skips those, so a suggestion
  /// cannot reinforce itself. Nothing sets it until 014 lands.
  bool categoryAutoSuggested = false;

  bool deleted = false;

  late DateTime createdAt;

  late DateTime updatedAt;

  @override
  @ignore
  String get entityType => 'transaction';

  @override
  Map<String, dynamic> toSyncPayload() => {
        'uuid': uuid,
        'accountUuid': accountUuid,
        'categoryUuid': categoryUuid,
        'amountCents': amountCents,
        'bookingDate': bookingDate.toIso8601String(),
        'description': description,
        'counterparty': counterparty,
        'note': note,
        'dedupeHash': dedupeHash,
        'categoryAutoSuggested': categoryAutoSuggested,
        'deleted': deleted,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
