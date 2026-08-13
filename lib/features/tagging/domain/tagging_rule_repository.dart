import 'package:isar_community/isar.dart';

import '../../../core/sync/sync_adapter.dart';
import '../../../core/sync/sync_op.dart';
import '../../../core/sync/syncable_entity.dart';
import '../data/tagging_rule.dart';

/// Persists learned [TaggingRule]s and mirrors every write to the sync
/// change-queue, per the repository-layer contract in docs/sync.md.
class TaggingRuleRepository {
  TaggingRuleRepository(this._isar, this._sync);

  final Isar _isar;
  final SyncAdapter _sync;

  /// Records one assignment: a known pair gains a hit, a new one is created.
  Future<TaggingRule> upsert(
    String matchValueNorm,
    String categoryUuid, {
    TaggingMatchField matchField = TaggingMatchField.counterparty,
  }) async {
    final now = DateTime.now();
    final existing = await _isar.taggingRules
        .filter()
        .matchValueNormEqualTo(matchValueNorm)
        .matchFieldEqualTo(matchField)
        .categoryUuidEqualTo(categoryUuid)
        .findFirst();

    if (existing != null) {
      existing
        ..hitCount += 1
        ..lastAssignedAt = now
        ..updatedAt = now;
      await _put(existing);
      await _sync.enqueue(SyncOp.update, existing);
      return existing;
    }

    final rule = TaggingRule()
      ..matchField = matchField
      ..matchValueNorm = matchValueNorm
      ..categoryUuid = categoryUuid
      ..hitCount = 1
      ..lastAssignedAt = now
      ..createdAt = now
      ..updatedAt = now;
    rule.ensureUuid();
    await _put(rule);
    await _sync.enqueue(SyncOp.create, rule);
    return rule;
  }

  /// Rules for one normalized counterparty, strongest first. Ticket 014 takes
  /// the head of this list as its suggestion.
  Future<List<TaggingRule>> findByCounterparty(String matchValueNorm) async {
    final rules = await _isar.taggingRules
        .filter()
        .matchValueNormEqualTo(matchValueNorm)
        .matchFieldEqualTo(TaggingMatchField.counterparty)
        .findAll();
    return rules..sort(_strongestFirst);
  }

  Future<List<TaggingRule>> findAll() async {
    final rules = await _isar.taggingRules.where().findAll();
    return rules..sort(_strongestFirst);
  }

  Future<TaggingRule?> findByUuid(String uuid) =>
      _isar.taggingRules.filter().uuidEqualTo(uuid).findFirst();

  /// Real delete, no soft-delete flag: an archived rule that keeps suggesting
  /// would be pointless, so removal *is* the domain operation here — same
  /// reasoning as `ImportedSource` (see decisions.md).
  Future<void> delete(String uuid) async {
    final rule = await findByUuid(uuid);
    if (rule == null) return;
    await _isar.writeTxn(() async {
      await _isar.taggingRules.delete(rule.id);
    });
    await _sync.enqueue(SyncOp.delete, rule);
  }

  /// Moves a rule to another category, keeping its learned history. Backs the
  /// "remap stale rule" action of ticket 025.
  Future<void> remap(String uuid, String categoryUuid) async {
    final rule = await findByUuid(uuid);
    if (rule == null) return;
    rule
      ..categoryUuid = categoryUuid
      ..updatedAt = DateTime.now();
    await _put(rule);
    await _sync.enqueue(SyncOp.update, rule);
  }

  Future<void> _put(TaggingRule rule) => _isar.writeTxn(() async {
        await _isar.taggingRules.put(rule);
      });

  static int _strongestFirst(TaggingRule a, TaggingRule b) {
    final byHits = b.hitCount.compareTo(a.hitCount);
    if (byHits != 0) return byHits;
    return b.lastAssignedAt.compareTo(a.lastAssignedAt);
  }
}
