import 'package:isar_community/isar.dart';

import '../../../core/sync/syncable_entity.dart';

part 'line_item.g.dart';

/// `restposten` rows are generated to keep the line-item sum equal to the
/// parent transaction (ticket 019); users create `regular` ones.
enum LineItemKind { regular, restposten }

/// One position of a [Transaction] (Kassenbon item). [amountCents] carries the
/// same sign as the parent transaction. Soft-deleted via [deleted].
@collection
class LineItem implements SyncableEntity {
  Id id = Isar.autoIncrement;

  @override
  @Index(unique: true)
  String uuid = '';

  @Index()
  late String transactionUuid;

  late int amountCents;

  /// Count or weight. Null when unknown — OCR fills what it can.
  double? quantity;

  /// Magnitude only, never signed. Null when unknown.
  int? unitPriceCents;

  late String description;

  /// Null means: inherit the parent transaction's category (ticket 012).
  @Index()
  String? categoryUuid;

  @Enumerated(EnumType.name)
  LineItemKind kind = LineItemKind.regular;

  /// Manual order within one transaction; gaps of 1000 leave room for inserts.
  int orderIndex = 0;

  bool deleted = false;

  late DateTime createdAt;

  late DateTime updatedAt;

  @override
  @ignore
  String get entityType => 'lineItem';

  @override
  Map<String, dynamic> toSyncPayload() => {
        'uuid': uuid,
        'transactionUuid': transactionUuid,
        'amountCents': amountCents,
        'quantity': quantity,
        'unitPriceCents': unitPriceCents,
        'description': description,
        'categoryUuid': categoryUuid,
        'kind': kind.name,
        'orderIndex': orderIndex,
        'deleted': deleted,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
