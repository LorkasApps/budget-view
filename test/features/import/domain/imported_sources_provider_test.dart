import 'dart:io';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/persistence/isar_provider.dart';
import 'package:budget_view/features/import/data/imported_source.dart';
import 'package:budget_view/features/import/data/imported_source_kind.dart';
import 'package:budget_view/features/import/domain/import_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

/// Covers the provider wiring rather than the sort, mirroring
/// monthly_report_reactivity_test.dart: a write to `ImportedSource` must push
/// a new value. Runs as a plain `test()` — Isar never completes inside
/// `testWidgets`' fake-async zone.
void main() {
  late Directory tempDir;
  late Isar isar;
  late ProviderContainer container;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_import_');
    isar = await openAppIsar(directory: tempDir.path);
    container = ProviderContainer(
      overrides: [isarProvider.overrideWithValue(isar)],
    );
    container.listen(
      importedSourcesProvider,
      (_, _) {},
      fireImmediately: true,
    );
  });

  tearDown(() async {
    container.dispose();
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<List<ImportedSource>> sourcesWhere(
    bool Function(List<ImportedSource> sources) predicate,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      final value = container.read(importedSourcesProvider).valueOrNull;
      if (value != null && predicate(value)) return value;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('imported sources never satisfied the predicate');
  }

  ImportedSource build({
    required String hash,
    required DateTime importedAt,
  }) {
    return ImportedSource()
      ..kind = ImportedSourceKind.pdf
      ..contentHashSha256 = hash
      ..filename = 'auszug.pdf'
      ..importedAt = importedAt
      ..transactionsProduced = 3
      ..lineItemsProduced = 0;
  }

  test('saving two rows emits both, newest importedAt first', () async {
    await sourcesWhere((sources) => sources.isEmpty);
    final repo = container.read(importedSourceRepositoryProvider);

    await repo.save(build(hash: 'a', importedAt: DateTime(2026, 6, 1)));
    await repo.save(build(hash: 'b', importedAt: DateTime(2026, 8, 1)));

    final updated = await sourcesWhere((sources) => sources.length == 2);
    expect(updated.map((source) => source.contentHashSha256), ['b', 'a']);
  });

  test('deleting a row emits again without it', () async {
    final repo = container.read(importedSourceRepositoryProvider);
    final first = await repo.save(
      build(hash: 'a', importedAt: DateTime(2026, 6, 1)),
    );
    await repo.save(build(hash: 'b', importedAt: DateTime(2026, 8, 1)));
    await sourcesWhere((sources) => sources.length == 2);

    await repo.delete(first.uuid);

    final updated = await sourcesWhere((sources) => sources.length == 1);
    expect(updated.single.contentHashSha256, 'b');
  });
}
