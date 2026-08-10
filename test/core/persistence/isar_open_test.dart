import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import 'package:budget_view/core/persistence/app_meta.dart';
import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/persistence/schema_version.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_isar_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('opens and seeds AppMeta on first launch', () async {
    final isar = await openAppIsar(directory: tempDir.path);

    final meta = await isar.appMetas.get(0);
    expect(meta, isNotNull);
    expect(meta!.schemaVersion, kDbSchemaVersion);
    expect(meta.installId, isNotEmpty);

    await isar.close();
  });

  test('reopening keeps the same installId (data survives)', () async {
    final isar1 = await openAppIsar(directory: tempDir.path);
    final firstId = (await isar1.appMetas.get(0))!.installId;
    await isar1.close();

    final isar2 = await openAppIsar(directory: tempDir.path);
    final secondId = (await isar2.appMetas.get(0))!.installId;
    await isar2.close();

    expect(secondId, firstId);
  });
}
