import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/sync/local_sync_adapter.dart';
import 'package:budget_view/features/category/data/category.dart';
import 'package:budget_view/features/category/domain/category_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

void main() {
  late Directory tempDir;
  late Isar isar;
  late CategoryRepository repo;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_category_');
    isar = await openAppIsar(directory: tempDir.path);
    repo = CategoryRepository(isar, LocalSyncAdapter(isar));
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Category build(String name, {String parent = '', int sort = 1000}) {
    return Category()
      ..name = name
      ..parentUuid = parent
      ..sortOrder = sort;
  }

  test('save assigns uuid + timestamps and trims the name', () async {
    final saved = await repo.save(build('  Wohnen  '));

    expect(saved.uuid, isNotEmpty);
    expect(saved.name, 'Wohnen');
    expect(saved.createdAt, isNotNull);
    expect(saved.updatedAt, isNotNull);
    expect(saved.isRoot, isTrue);
  });

  test('save rejects an empty name', () async {
    expect(
      () => repo.save(build('   ')),
      throwsA(isA<CategoryInvalid>()),
    );
  });

  test('save rejects a duplicate sibling name regardless of case', () async {
    await repo.save(build('Einkauf'));

    expect(
      () => repo.save(build('einkauf')),
      throwsA(isA<CategoryInvalid>()),
    );
  });

  test('the same name is allowed under a different parent', () async {
    final wohnen = await repo.save(build('Wohnen'));
    final mobil = await repo.save(build('Mobilität'));

    await repo.save(build('Rückerstattung', parent: wohnen.uuid));
    final second = await repo.save(build('Rückerstattung', parent: mobil.uuid));

    expect(second.uuid, isNotEmpty);
  });

  test('an archived sibling frees its name', () async {
    final first = await repo.save(build('Strom'));
    await repo.delete(first.uuid);

    final second = await repo.save(build('Strom'));

    expect(second.uuid, isNot(first.uuid));
  });

  test('save rejects a parent that does not exist', () async {
    expect(
      () => repo.save(build('Strom', parent: 'nope')),
      throwsA(isA<CategoryInvalid>()),
    );
  });

  test('save rejects a category as its own parent', () async {
    final saved = await repo.save(build('Wohnen'));
    saved.parentUuid = saved.uuid;

    expect(() => repo.save(saved), throwsA(isA<CategoryInvalid>()));
  });

  test('save rejects a move that would close a cycle', () async {
    final parent = await repo.save(build('Wohnen'));
    final child = await repo.save(build('Strom', parent: parent.uuid));

    parent.parentUuid = child.uuid;

    expect(() => repo.save(parent), throwsA(isA<CategoryInvalid>()));
  });

  test('delete blocks while children exist and reports the count', () async {
    final parent = await repo.save(build('Wohnen'));
    await repo.save(build('Strom', parent: parent.uuid));
    await repo.save(build('Wasser', parent: parent.uuid));

    try {
      await repo.delete(parent.uuid);
      fail('expected CategoryDeleteBlocked');
    } on CategoryDeleteBlocked catch (error) {
      expect(error.childCount, 2);
      expect(error.transactionCount, 0);
      expect(error.message, contains('2 Unterkategorien'));
    }
  });

  test('delete archives a leaf and restore brings it back', () async {
    final leaf = await repo.save(build('Strom'));

    await repo.delete(leaf.uuid);
    expect((await repo.findByUuid(leaf.uuid))!.archived, isTrue);
    expect(await repo.findAll(), isEmpty);
    expect(await repo.findAll(includeArchived: true), hasLength(1));

    await repo.restore(leaf.uuid);
    expect((await repo.findByUuid(leaf.uuid))!.archived, isFalse);
  });

  test('findRoots and findChildren sort by sortOrder then name', () async {
    final parent = await repo.save(build('Wohnen', sort: 2000));
    await repo.save(build('Mobilität', sort: 1000));
    await repo.save(build('Wasser', parent: parent.uuid, sort: 2000));
    await repo.save(build('Strom', parent: parent.uuid, sort: 1000));

    expect(
      (await repo.findRoots()).map((c) => c.name),
      ['Mobilität', 'Wohnen'],
    );
    expect(
      (await repo.findChildren(parent.uuid)).map((c) => c.name),
      ['Strom', 'Wasser'],
    );
  });

  test('reorderSiblings renumbers sortOrder in the given order', () async {
    final first = await repo.save(build('A', sort: 1000));
    final second = await repo.save(build('B', sort: 2000));

    await repo.reorderSiblings([second, first]);

    final roots = await repo.findRoots();
    expect(roots.map((c) => c.name), ['B', 'A']);
    expect(roots.first.sortOrder, 1000);
    expect(roots.last.sortOrder, 2000);
  });
}
