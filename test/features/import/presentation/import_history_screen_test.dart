import 'package:budget_view/core/format/date_format.dart';
import 'package:budget_view/features/import/data/imported_source.dart';
import 'package:budget_view/features/import/data/imported_source_kind.dart';
import 'package:budget_view/features/import/domain/import_providers.dart';
import 'package:budget_view/features/import/domain/imported_source_repository.dart';
import 'package:budget_view/features/import/presentation/import_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the uuids passed to `delete` and counts calls to every other
/// method, so a test can assert deletion is the only thing the screen
/// reaches for. `implements` (not `extends`) means the real constructor,
/// which wants a working `Isar` and `SyncAdapter`, is never called.
class _RecordingImportedSourceRepository implements ImportedSourceRepository {
  final List<String> deleted = [];
  int otherCalls = 0;

  @override
  Future<void> delete(String uuid) async {
    deleted.add(uuid);
  }

  @override
  Future<ImportedSource> save(ImportedSource source) async {
    otherCalls++;
    return source;
  }

  @override
  Future<List<ImportedSource>> findByHash(String contentHashSha256) async {
    otherCalls++;
    return const [];
  }

  @override
  Future<List<ImportedSource>> findAll() async {
    otherCalls++;
    return const [];
  }

  @override
  Future<ImportedSource?> findByUuid(String uuid) async {
    otherCalls++;
    return null;
  }
}

ImportedSource _source({
  required String uuid,
  required ImportedSourceKind kind,
  String filename = '',
  int transactionsProduced = 1,
  int lineItemsProduced = 0,
}) {
  final now = DateTime(2026, 3, 1);
  return ImportedSource()
    ..uuid = uuid
    ..kind = kind
    ..contentHashSha256 = 'hash-$uuid'
    ..filename = filename
    ..importedAt = now
    ..transactionsProduced = transactionsProduced
    ..lineItemsProduced = lineItemsProduced
    ..note = null
    ..createdAt = now
    ..updatedAt = now;
}

void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// A fling rather than a drag: it carries velocity, so the dismissal fires
  /// without the swipe having to clear the 40 % width threshold on its own.
  Future<void> swipeAway(WidgetTester tester, Finder row) async {
    await tester.fling(row, const Offset(-800, 0), 2000);
    await tester.pumpAndSettle();
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required List<ImportedSource> sources,
    required _RecordingImportedSourceRepository repository,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          importedSourcesProvider.overrideWith(
            (ref) => Stream.value(sources),
          ),
          importedSourceRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: ImportHistoryScreen()),
      ),
    );
    await settle(tester);
  }

  testWidgets('a pdf row shows its filename, a photo row shows Foto', (
    tester,
  ) async {
    final pdf = _source(
      uuid: 'pdf-1',
      kind: ImportedSourceKind.pdf,
      filename: 'kontoauszug.pdf',
      transactionsProduced: 1,
    );
    final photo = _source(
      uuid: 'photo-1',
      kind: ImportedSourceKind.photo,
      transactionsProduced: 12,
      lineItemsProduced: 3,
    );
    await pumpScreen(
      tester,
      sources: [pdf, photo],
      repository: _RecordingImportedSourceRepository(),
    );

    expect(find.text('kontoauszug.pdf'), findsOneWidget);
    expect(find.text('Foto'), findsOneWidget);

    final date = formatDateDe(DateTime(2026, 3, 1));
    expect(find.textContaining(date), findsNWidgets(2));
    expect(find.textContaining('1 Buchung'), findsOneWidget);
    expect(find.textContaining('12 Buchungen'), findsOneWidget);
    expect(find.textContaining('Positionen'), findsOneWidget);
  });

  testWidgets(
    'swiping shows a confirm dialog and Abbrechen leaves nothing deleted',
    (tester) async {
      final repository = _RecordingImportedSourceRepository();
      await pumpScreen(
        tester,
        sources: [
          _source(
            uuid: 'pdf-1',
            kind: ImportedSourceKind.pdf,
            filename: 'a.pdf',
          ),
        ],
        repository: repository,
      );

      await swipeAway(tester, find.byType(Dismissible));

      expect(
        find.textContaining('Buchungen bleiben erhalten'),
        findsOneWidget,
      );

      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      expect(repository.deleted, isEmpty);
    },
  );

  testWidgets('swiping and confirming deletes only that row via delete', (
    tester,
  ) async {
    final repository = _RecordingImportedSourceRepository();
    await pumpScreen(
      tester,
      sources: [
        _source(uuid: 'pdf-1', kind: ImportedSourceKind.pdf, filename: 'a.pdf'),
        _source(
          uuid: 'pdf-2',
          kind: ImportedSourceKind.pdf,
          filename: 'b.pdf',
        ),
      ],
      repository: repository,
    );

    await swipeAway(tester, find.text('a.pdf'));

    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(repository.deleted, ['pdf-1']);
    expect(repository.otherCalls, 0);
  });

  testWidgets('an empty list shows the empty-state hint', (tester) async {
    await pumpScreen(
      tester,
      sources: const [],
      repository: _RecordingImportedSourceRepository(),
    );

    expect(find.text('Noch keine Importe.'), findsOneWidget);
  });
}
