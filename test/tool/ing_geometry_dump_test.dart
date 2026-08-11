import 'dart:io';
import 'dart:ui' show Rect;

import 'package:budget_view/features/transaction/import/pdf/ing_giro_parser.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Diagnostic harness, not an assertion. Dumps per-line and per-word geometry of
/// a real statement so the parser's column detection can be calibrated against
/// actual coordinates instead of guessed ones.
///
/// Skipped unless `ING_PDF` is set, so it stays inert in `make check`. Output
/// goes to a temp file on purpose — statements hold real account data and must
/// never land inside the repo.
///
///     ING_PDF=/path/auszug.pdf flutter test test/tool/ing_geometry_dump_test.dart
void main() {
  _reconciliationTest();

  test('dump ING statement geometry', () async {
    final source = Platform.environment['ING_PDF'];
    if (source == null || source.isEmpty) {
      markTestSkipped(
        'set ING_PDF=/path/to/statement.pdf to dump geometry',
      );
      return;
    }

    final pageCount = int.tryParse(Platform.environment['ING_PAGES'] ?? '') ?? 2;
    final target = Platform.environment['ING_DUMP_OUT'] ??
        '${Directory.systemTemp.path}/ing_geometry.tsv';

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

    final leftBuckets = <int, int>{};
    for (final line in lines) {
      for (final word in line.wordCollection) {
        final bucket = (word.bounds.left / 5).round() * 5;
        leftBuckets[bucket] = (leftBuckets[bucket] ?? 0) + 1;
      }
    }
    final ranked = leftBuckets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    stdout.writeln('pages 1..$pageCount -> $target');
    stdout.writeln('${lines.length} text lines');
    stdout.writeln('word x-left buckets (5pt, most frequent first):');
    for (final entry in ranked.take(15)) {
      stdout.writeln('  x=${entry.key}\t${entry.value} words');
    }
  });
}

/// Runs the real parser over a real statement and reports totals. The sum of
/// all bookings must equal `Neuer Saldo - Alter Saldo` from the statement head,
/// which is a stronger check than any synthetic fixture can give.
void _reconciliationTest() {
  test('parse a real ING statement and report totals', () async {
    final source = Platform.environment['ING_PDF'];
    if (source == null || source.isEmpty) {
      markTestSkipped('set ING_PDF=/path/to/statement.pdf to reconcile');
      return;
    }

    final result = await const IngGiroParser()
        .parse(await File(source).readAsBytes());
    final sum = result.transactions.fold<int>(
      0,
      (total, candidate) => total + candidate.amountCents,
    );

    // Totals last: they are the point of this run and must not scroll away.
    for (final candidate in result.transactions.take(3)) {
      stdout.writeln(
        '  ${candidate.bookingDate.toIso8601String().substring(0, 10)} '
        '| ${candidate.amountCents} '
        '| ${candidate.counterparty} '
        '| ${candidate.description}',
      );
    }
    for (final warning in result.warnings.take(5)) {
      stdout.writeln('  warn: $warning');
    }
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
