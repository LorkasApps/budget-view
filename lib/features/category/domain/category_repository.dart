import 'package:isar_community/isar.dart';

import '../../../core/sync/sync_adapter.dart';
import '../../../core/sync/sync_op.dart';
import '../../../core/sync/syncable_entity.dart';
import '../data/category.dart';
import 'category_validation.dart';

/// A save was rejected by a tree rule. Carries a message meant for the user.
class CategoryInvalid implements Exception {
  const CategoryInvalid(this.message);

  final String message;

  @override
  String toString() => 'CategoryInvalid: $message';
}

/// A delete was refused because the category is still in use. Counts are part
/// of the contract: the UI tells the user what to move before retrying.
class CategoryDeleteBlocked implements Exception {
  const CategoryDeleteBlocked({
    required this.childCount,
    required this.transactionCount,
  });

  final int childCount;
  final int transactionCount;

  String get message {
    final blockers = <String>[
      if (childCount > 0) '$childCount Unterkategorien',
      if (transactionCount > 0) '$transactionCount Buchungen',
    ];
    return 'Kategorie hat ${blockers.join(' und ')} — bitte zuerst verschieben.';
  }

  @override
  String toString() => 'CategoryDeleteBlocked: $message';
}

/// Persists the category tree and mirrors every write to the sync change-queue,
/// per the repository-layer contract in docs/sync.md.
class CategoryRepository {
  CategoryRepository(this._isar, this._sync);

  final Isar _isar;
  final SyncAdapter _sync;

  Future<Category> save(Category category) async {
    await _assertSavable(category);

    final isNew = category.uuid.isEmpty;
    category.ensureUuid();
    category.name = category.name.trim();
    final now = DateTime.now();
    if (isNew) {
      category.createdAt = now;
    }
    category.updatedAt = now;

    await _isar.writeTxn(() async {
      await _isar.categorys.put(category);
    });
    await _sync.enqueue(isNew ? SyncOp.create : SyncOp.update, category);
    return category;
  }

  /// Soft-deletes by archiving. Throws [CategoryDeleteBlocked] while anything
  /// still hangs off the category.
  Future<void> delete(String uuid) async {
    final category = await findByUuid(uuid);
    if (category == null || category.archived) return;

    final childCount =
        await _isar.categorys.filter().parentUuidEqualTo(uuid).count();
    // Transactions cannot reference a category yet; ticket 011 adds the field
    // and fills this in.
    const transactionCount = 0;
    if (childCount > 0 || transactionCount > 0) {
      throw CategoryDeleteBlocked(
        childCount: childCount,
        transactionCount: transactionCount,
      );
    }

    category.archived = true;
    category.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.categorys.put(category);
    });
    await _sync.enqueue(SyncOp.delete, category);
  }

  Future<void> restore(String uuid) async {
    final category = await findByUuid(uuid);
    if (category == null || !category.archived) return;

    category.archived = false;
    category.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.categorys.put(category);
    });
    await _sync.enqueue(SyncOp.update, category);
  }

  /// Rewrites `sortOrder` to match the given order. Only changed rows are
  /// written, so a no-op drag does not flood the change-queue.
  Future<void> reorderSiblings(List<Category> ordered) async {
    final changed = <Category>[];
    for (var index = 0; index < ordered.length; index++) {
      final wanted = (index + 1) * 1000;
      final category = ordered[index];
      if (category.sortOrder == wanted) continue;
      category.sortOrder = wanted;
      category.updatedAt = DateTime.now();
      changed.add(category);
    }
    if (changed.isEmpty) return;

    await _isar.writeTxn(() async {
      await _isar.categorys.putAll(changed);
    });
    for (final category in changed) {
      await _sync.enqueue(SyncOp.update, category);
    }
  }

  Future<Category?> findByUuid(String uuid) =>
      _isar.categorys.filter().uuidEqualTo(uuid).findFirst();

  Future<List<Category>> findAll({bool includeArchived = false}) {
    if (includeArchived) {
      return _isar.categorys
          .where()
          .sortBySortOrder()
          .thenByName()
          .findAll();
    }
    return _isar.categorys
        .filter()
        .archivedEqualTo(false)
        .sortBySortOrder()
        .thenByName()
        .findAll();
  }

  Future<List<Category>> findChildren(String parentUuid) => _isar.categorys
      .filter()
      .parentUuidEqualTo(parentUuid)
      .sortBySortOrder()
      .thenByName()
      .findAll();

  Future<List<Category>> findRoots() => findChildren('');

  Future<void> _assertSavable(Category category) async {
    final nameError = CategoryValidation.name(category.name);
    if (nameError != null) throw CategoryInvalid(nameError);

    if (category.parentUuid == category.uuid && category.uuid.isNotEmpty) {
      throw const CategoryInvalid(
        'Eine Kategorie kann nicht ihr eigenes Elternteil sein',
      );
    }

    if (category.parentUuid.isNotEmpty) {
      final parent = await findByUuid(category.parentUuid);
      if (parent == null) {
        throw const CategoryInvalid(
          'Übergeordnete Kategorie existiert nicht',
        );
      }
      if (await _wouldCycle(category)) {
        throw const CategoryInvalid(
          'Verschieben würde einen Zirkel erzeugen',
        );
      }
    }

    if (await _siblingNameTaken(category)) {
      throw const CategoryInvalid(
        'Auf dieser Ebene existiert der Name bereits',
      );
    }
  }

  /// Walks ancestors of the intended parent; reaching the category itself means
  /// the move would close a loop.
  Future<bool> _wouldCycle(Category category) async {
    if (category.uuid.isEmpty) return false;

    var cursor = category.parentUuid;
    final seen = <String>{};
    while (cursor.isNotEmpty) {
      if (cursor == category.uuid) return true;
      if (!seen.add(cursor)) return true; // pre-existing loop, do not spin
      final parent = await findByUuid(cursor);
      if (parent == null) return false;
      cursor = parent.parentUuid;
    }
    return false;
  }

  /// Names are unique per level, compared case-insensitively so `Einkauf` and
  /// `einkauf` cannot coexist as siblings. Archived siblings free their name.
  Future<bool> _siblingNameTaken(Category category) async {
    final siblings = await _isar.categorys
        .filter()
        .parentUuidEqualTo(category.parentUuid)
        .archivedEqualTo(false)
        .findAll();

    final name = category.name.trim().toLowerCase();
    return siblings.any(
      (sibling) =>
          sibling.uuid != category.uuid &&
          sibling.name.trim().toLowerCase() == name,
    );
  }
}
