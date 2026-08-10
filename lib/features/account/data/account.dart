import 'package:isar_community/isar.dart';

import '../../../core/sync/syncable_entity.dart';
import 'account_type.dart';

part 'account.g.dart';

/// A bank account (Giro, Tagesgeld, ...). Soft-deleted via [archived].
/// Money is signed integer cents; negative opening balance allowed (Kredit).
@collection
class Account implements SyncableEntity {
  Id id = Isar.autoIncrement;

  @override
  @Index(unique: true)
  String uuid = '';

  late String name;

  @enumerated
  late AccountType type;

  late int openingBalanceCents;

  late DateTime openingDate;

  bool archived = false;

  late DateTime createdAt;

  late DateTime updatedAt;

  @override
  @ignore
  String get entityType => 'account';

  @override
  Map<String, dynamic> toSyncPayload() => {
        'uuid': uuid,
        'name': name,
        'type': type.name,
        'openingBalanceCents': openingBalanceCents,
        'openingDate': openingDate.toIso8601String(),
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
