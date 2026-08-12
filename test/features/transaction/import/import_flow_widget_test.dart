import 'dart:typed_data';

import 'package:budget_view/features/account/data/account.dart';
import 'package:budget_view/features/account/data/account_type.dart';
import 'package:budget_view/features/account/domain/account_providers.dart';
import 'package:budget_view/features/import/data/imported_source.dart';
import 'package:budget_view/features/import/domain/duplicate_checker.dart';
import 'package:budget_view/features/import/domain/import_providers.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:budget_view/features/transaction/import/domain/import_flow_controller.dart';
import 'package:budget_view/features/transaction/import/pdf/parse_result.dart';
import 'package:budget_view/features/transaction/import/pdf/pdf_parser.dart';
import 'package:budget_view/features/transaction/import/pdf/pdf_parser_providers.dart';
import 'package:budget_view/features/transaction/import/pdf/pdf_parser_registry.dart';
import 'package:budget_view/features/transaction/import/presentation/pdf_import_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// UI wiring only, deliberately without a database.
///
/// A `testWidgets` body runs in a fake-async zone in which real Isar I/O never
/// completes — the run hangs instead of failing, and `--timeout` does not fire.
/// So every provider this screen touches is overridden with pure Dart, and the
/// persistence path (import button → `persist` → repository) is covered by
/// `import_flow_controller_test.dart`, which runs outside the widget zone.
class _StubParser implements PdfParser {
  @override
  String get id => 'stub-giro';

  @override
  String get displayName => 'Stub Giro';

  @override
  Future<double> canParse(Uint8List bytes) async => 0.9;

  @override
  Future<ParseResult> parse(Uint8List bytes) async => ParseResult(
        transactions: [
          ParsedTransactionCandidate(
            bookingDate: DateTime(2026, 7, 1),
            amountCents: -12600,
            description: 'Abschlag Strom',
            counterparty: 'Belkaw GmbH',
          ),
          ParsedTransactionCandidate(
            bookingDate: DateTime(2026, 7, 14),
            amountCents: 300000,
            description: 'Gehalt',
            counterparty: 'RTL',
          ),
        ],
        warnings: const ['Zeile 42 unlesbar'],
      );
}

/// Duplicate detection queries Isar, which never completes in the widget zone.
/// The dedupe behaviour itself is covered by the controller and checker tests.
class _NoDuplicates implements DuplicateChecker {
  const _NoDuplicates();

  @override
  Future<List<Transaction>> findTransactionMatches(
    String dedupeHash, {
    required String accountUuid,
    bool excludeDeleted = true,
  }) async =>
      const [];

  @override
  Future<List<ImportedSource>> findDocumentMatches(String contentHash) async =>
      const [];
}

void main() {
  late ProviderContainer container;

  final account = Account()
    ..uuid = 'account-1'
    ..name = 'ING Giro'
    ..type = AccountType.giro
    ..openingBalanceCents = 100000
    ..openingDate = DateTime(2026, 1, 1);

  setUp(() {
    container = ProviderContainer(
      overrides: [
        pdfParserRegistryProvider.overrideWithValue(
          PdfParserRegistry()..register(_StubParser()),
        ),
        accountsProvider(false).overrideWith((ref) => Stream.value([account])),
        duplicateCheckerProvider.overrideWithValue(const _NoDuplicates()),
      ],
    );
  });

  tearDown(() => container.dispose());

  /// Frames are pumped with explicit durations rather than `pumpAndSettle`,
  /// because the account dropdown's indeterminate progress indicator schedules
  /// frames forever and would keep `pumpAndSettle` spinning until its timeout.
  ///
  /// The window has to outlast a dialog's exit transition — otherwise the
  /// dismissed dialog's `EditableText` is still mounted and duplicates the text
  /// the assertions look for.
  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pumpFlow(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: PdfImportScreen(accountUuid: account.uuid)),
      ),
    );
    await settle(tester);
  }

  Future<void> loadAndParse(WidgetTester tester) async {
    final controller = container.read(importFlowProvider.notifier);
    await controller.loadDocument(
      Uint8List.fromList([1, 2, 3]),
      fileName: 'auszug.pdf',
    );
    await controller.parseDocument();
    await settle(tester);
  }

  testWidgets('parsed rows are listed with amounts, warnings and target', (
    tester,
  ) async {
    await pumpFlow(tester);
    await loadAndParse(tester);

    expect(find.text('auszug.pdf'), findsOneWidget);
    expect(find.text('2 von 2 ausgewählt'), findsOneWidget);
    expect(find.text('Abschlag Strom'), findsOneWidget);
    expect(find.text('Gehalt'), findsOneWidget);
    expect(find.textContaining('Zeile 42 unlesbar'), findsOneWidget);
    expect(find.text('ING Giro'), findsOneWidget);
    expect(find.text('2 Buchungen importieren'), findsOneWidget);
  });

  testWidgets('the parser choice is shown before parsing, gone after', (
    tester,
  ) async {
    await pumpFlow(tester);

    final controller = container.read(importFlowProvider.notifier);
    await controller.loadDocument(
      Uint8List.fromList([1, 2, 3]),
      fileName: 'auszug.pdf',
    );
    await settle(tester);

    expect(find.text('Stub Giro'), findsOneWidget);
    expect(find.text('90 % Konfidenz'), findsOneWidget);

    await tester.tap(find.text('Auslesen'));
    await settle(tester);

    expect(find.text('Stub Giro'), findsNothing);
    expect(find.text('2 von 2 ausgewählt'), findsOneWidget);
  });

  testWidgets('excluding a row updates the count and the import button', (
    tester,
  ) async {
    await pumpFlow(tester);
    await loadAndParse(tester);

    await tester.tap(find.byType(Checkbox).first);
    await settle(tester);

    expect(find.text('1 von 2 ausgewählt'), findsOneWidget);
    expect(find.text('1 Buchungen importieren'), findsOneWidget);
    expect(container.read(importFlowProvider).rows.first.included, isFalse);
  });

  testWidgets('excluding every row disables the import button', (tester) async {
    await pumpFlow(tester);
    await loadAndParse(tester);

    await tester.tap(find.byType(Checkbox).first);
    await settle(tester);
    await tester.tap(find.byType(Checkbox).last);
    await settle(tester);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '0 Buchungen importieren'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('editing a row rewrites its fields', (tester) async {
    await pumpFlow(tester);
    await loadAndParse(tester);

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await settle(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Verwendungszweck'),
      'Abschlag Gas',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Betrag (EUR)'),
      '99,50',
    );
    await tester.tap(find.text('Übernehmen'));
    await settle(tester);

    final row = container.read(importFlowProvider).rows.first;
    expect(row.description, 'Abschlag Gas');
    expect(row.amountCents, -9950);
    expect(row.counterparty, 'Belkaw GmbH');
    expect(find.text('Abschlag Gas'), findsOneWidget);
  });

  testWidgets('cancelling the edit dialog leaves the row untouched', (
    tester,
  ) async {
    await pumpFlow(tester);
    await loadAndParse(tester);

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Verwendungszweck'),
      'Verworfen',
    );
    await tester.tap(find.text('Abbrechen'));
    await settle(tester);

    expect(container.read(importFlowProvider).rows.first.description,
        'Abschlag Strom');
    expect(find.text('Verworfen'), findsNothing);
  });
}
