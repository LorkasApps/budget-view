import 'dart:io';
import 'dart:ui' show Rect;

import 'package:budget_view/features/transaction/import/pdf/trade_republic_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Diagnostic harness, not an assertion. Dumps per-line and per-word geometry of
/// a real Trade Republic cash statement so the column detection can be
/// calibrated against actual coordinates instead of guessed ones.
///
/// Skipped unless `TR_PDF` is set, so it stays inert in `make check`. Output goes
/// to a temp file on purpose — statements hold real account data and must never
/// land inside the repo.
///
///     TR_PDF=/path/kontoauszug.pdf flutter test test/tool/trade_republic_geometry_dump_test.dart
void main() {
  _reconciliationTest();

  test('dump Trade Republic statement geometry', () async {
    final source = Platform.environment['TR_PDF'];
    if (source == null || source.isEmpty) {
      markTestSkipped('set TR_PDF=/path/to/statement.pdf to dump geometry');
      return;
    }

    final pageCount = int.tryParse(Platform.environment['TR_PAGES'] ?? '') ?? 2;
    final target =
        Platform.environment['TR_DUMP_OUT'] ??
        '${Directory.systemTemp.path}/trade_republic_geometry.tsv';

    final document = PdfDocument(inputBytes: await File(source).readAsBytes());
    final lines = PdfTextExtractor(document).extractTextLines(
      startPageIndex: 0,
      endPageIndex: pageCount - 1,
    );
    document.dispose();

    final sink = File(target).openWrite();
    sink.writeln('page\tkind\tleft\ttop\twidth\theight\ttext');
    for (final line in lines) {
      sink.writeln(_row(line.pageIndex, 'line', line.bounds, line.text));
      for (final word in line.wordCollection) {
        sink.writeln(_row(line.pageIndex, 'word', word.bounds, word.text));
      }
    }
    await sink.flush();
    await sink.close();

    // The header labels are what the parser derives its columns from, so their
    // coordinates are the ones worth seeing at a glance.
    const labels = {
      'DATUM',
      'TYP',
      'BESCHREIBUNG',
      'ZAHLUNGSEINGANG',
      'ZAHLUNGSAUSGANG',
      'SALDO',
      'ANFANGSSALDO',
      'ENDSALDO',
    };
    stdout.writeln('pages 1..$pageCount -> $target');
    stdout.writeln('${lines.length} text lines');
    stdout.writeln('header labels found:');
    for (final line in lines) {
      for (final word in line.wordCollection) {
        final text = word.text.trim();
        if (labels.contains(text)) {
          stdout.writeln(
            '  p${line.pageIndex} x=${word.bounds.left.toStringAsFixed(1)} '
            'y=${word.bounds.top.toStringAsFixed(1)} $text',
          );
        }
      }
    }
  });
}

/// Runs the real parser over a real statement and reports totals. The rows must
/// sum to `ENDSALDO - ANFANGSSALDO` of the Kontoübersicht, which is a stronger
/// check than any synthetic fixture can give — and the parser refuses the
/// statement when it fails, so an empty result with that warning is the signal.
void _reconciliationTest() {
  test('parse a real Trade Republic statement and report totals', () async {
    final source = Platform.environment['TR_PDF'];
    if (source == null || source.isEmpty) {
      markTestSkipped('set TR_PDF=/path/to/statement.pdf to reconcile');
      return;
    }

    final result = await const TradeRepublicParser().parse(
      await File(source).readAsBytes(),
    );
    final sum = result.transactions.fold<int>(
      0,
      (total, candidate) => total + candidate.amountCents,
    );

    for (final candidate in result.transactions) {
      stdout.writeln(
        '  ${candidate.bookingDate.toIso8601String().substring(0, 10)} '
        '| ${candidate.amountCents} '
        '| ${candidate.counterparty} '
        '| ${candidate.description}',
      );
    }
    for (final warning in result.warnings) {
      stdout.writeln('  warn: $warning');
    }
    // Totals last: they are the point of this run and must not scroll away.
    stdout.writeln('=== bookings: ${result.transactions.length}');
    stdout.writeln('=== sum: $sum cents');
    stdout.writeln('=== closing balance: ${result.statementBalanceCents}');
    stdout.writeln('=== warnings: ${result.warnings.length}');
  });
}

String _row(int page, String kind, Rect bounds, String text) {
  final clean = text.replaceAll(RegExp(r'[\t\r\n]+'), ' ').trim();
  return '$page\t$kind\t${bounds.left.toStringAsFixed(1)}\t'
      '${bounds.top.toStringAsFixed(1)}\t${bounds.width.toStringAsFixed(1)}\t'
      '${bounds.height.toStringAsFixed(1)}\t$clean';
}
