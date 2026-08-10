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

  late int amountCents;

  late DateTime bookingDate;

  late String description;

  String counterparty = '';

  String note = '';

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
        'amountCents': amountCents,
        'bookingDate': bookingDate.toIso8601String(),
        'description': description,
        'counterparty': counterparty,
        'note': note,
        'deleted': deleted,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
