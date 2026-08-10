import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

import 'package:budget_view/core/persistence/isar_db.dart';
import 'package:budget_view/core/persistence/isar_provider.dart';
import 'package:budget_view/main.dart';

void main() {
  late Directory tempDir;
  late Isar isar;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_app_');
    isar = await openAppIsar(directory: tempDir.path);
  });

  tearDown(() async {
    await isar.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('app boots to the account list', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isarProvider.overrideWithValue(isar)],
        child: const BudgetViewApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Konten'), findsOneWidget);
    expect(find.text('Noch keine Konten. Lege eins an.'), findsOneWidget);
  });
}
