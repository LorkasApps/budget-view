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
    tempDir = await Directory.systemTemp.createTemp('budgetview_schema_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('reconciles a stale schemaVersion up to the current one', () async {
    final isar1 = await openAppIsar(directory: tempDir.path);
    await isar1.writeTxn(() async {
      final meta = await isar1.appMetas.get(0);
      await isar1.appMetas.put(meta!..schemaVersion = 0);
    });
    await isar1.close();

    final isar2 = await openAppIsar(directory: tempDir.path);
    final meta = await isar2.appMetas.get(0);
    expect(meta!.schemaVersion, kDbSchemaVersion);
    await isar2.close();
  });
}
