import 'package:isar_community/isar.dart';

import '../../../core/sync/syncable_entity.dart';

part 'transaction.g.dart';

/// What a booking means beyond its sign.
///
/// A [transfer] moves money between the user's own accounts: it leaves one
/// balance and arrives in another, so it is neither spending nor income and the
/// report leaves it out of both. The sign alone cannot express that — the
/// outgoing leg looks exactly like a purchase (ticket 032).
enum TransactionKind { regular, transfer }

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

  /// Who the money really went to when [counterparty] is a collective payer such
  /// as PayPal, read out of the purpose text on import (ticket 047). Empty for
  /// everything else. Deliberately beside [counterparty] rather than replacing
  /// it: that field is the booking's identity and feeds [dedupeHash], which must
  /// not depend on a parser heuristic.
  String merchant = '';

  String note = '';

  /// SHA-256 of amount + booking day + normalised counterparty. Maintained by
  /// the repository on every write; see `domain/dedupe_hash.dart`.
  @Index()
  String dedupeHash = '';

  /// True while the category came from an accepted auto-suggestion (ticket 014)
  /// rather than the user. The tagging learn hook skips those, so a suggestion
  /// cannot reinforce itself. Nothing sets it until 014 lands.
  bool categoryAutoSuggested = false;

  /// Stored by name so the payload stays readable and a later value cannot
  /// shift meaning by index.
  @Enumerated(EnumType.name)
  TransactionKind kind = TransactionKind.regular;

  /// The [uuid] of the other leg of a transfer, once the user named a target
  /// account (ticket 042). Null for every other booking, and for a transfer
  /// whose money left the app — `Umbuchung` without a target stays legal.
  ///
  /// A written link rather than read-time matching on amount, day and the two
  /// accounts: that heuristic invents connections, since two coincidentally
  /// equal amounts on one day are not a transfer (`decisions.md`, 2026-08-21).
  /// No index — the value *is* the other row's unique-indexed `uuid`.
  String? counterpartUuid;

  bool deleted = false;

  late DateTime createdAt;

  late DateTime updatedAt;

  @override
  @ignore
  String get entityType => 'transaction';

  /// What tagging learns and suggests on: the merchant when one was read, the
  /// counterparty otherwise. One definition, so all three learn call sites and
  /// both suggest paths key on the same string (ticket 047).
  @ignore
  String get taggingKey => merchant.isEmpty ? counterparty : merchant;

  @override
  Map<String, dynamic> toSyncPayload() => {
        'uuid': uuid,
        'accountUuid': accountUuid,
        'categoryUuid': categoryUuid,
        'amountCents': amountCents,
        'bookingDate': bookingDate.toIso8601String(),
        'description': description,
        'counterparty': counterparty,
        'merchant': merchant,
        'note': note,
        'dedupeHash': dedupeHash,
        'categoryAutoSuggested': categoryAutoSuggested,
        'kind': kind.name,
        'counterpartUuid': counterpartUuid,
        'deleted': deleted,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
