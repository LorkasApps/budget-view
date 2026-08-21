import 'dart:io';

import 'package:budget_view/features/drilldown/scan/data/pdf_receipt_parser.dart';
import 'package:budget_view/features/drilldown/scan/data/receipt_pdf_words.dart';
import 'package:flutter_test/flutter_test.dart';

/// Diagnostic harness, not an assertion. Runs the receipt PDF parser over a real
/// document and reports what it decided, so the block tolerance, the price column
/// and the skip vocabulary get calibrated against actual coordinates.
///
/// Skipped unless `RECEIPT_PDF` is set, so it stays inert in `make check`. No
/// document ever enters the repo — receipts carry real purchase data.
///
///     RECEIPT_PDF=/tmp/Bon.pdf flutter test test/tool/receipt_pdf_dump_test.dart
void main() {
  test('parse a real receipt PDF and report what was decided', () async {
    final source = Platform.environment['RECEIPT_PDF'];
    if (source == null || source.isEmpty) {
      markTestSkipped('set RECEIPT_PDF=/path/to/receipt.pdf to dump decisions');
      return;
    }

    final words = extractReceiptWords(await File(source).readAsBytes());
    if (words.isEmpty) {
      stdout.writeln('no text layer — this document needs the OCR path');
      return;
    }

    // Full word list to a file: the aggregates below hide exactly the detail a
    // layout question needs, and stdout truncates.
    final target = Platform.environment['RECEIPT_DUMP_OUT'] ??
        '${Directory.systemTemp.path}/receipt_words.tsv';
    final sink = File(target).openWrite();
    sink.writeln('page\tleft\ttop\twidth\theight\ttext');
    for (final word in words) {
      sink.writeln(
        '${word.page}\t${word.left.toStringAsFixed(1)}\t'
        '${word.top.toStringAsFixed(1)}\t${word.width.toStringAsFixed(1)}\t'
        '${word.height.toStringAsFixed(1)}\t'
        '${word.text.replaceAll(RegExp(r'[\t\r\n]+'), ' ')}',
      );
    }
    await sink.flush();
    await sink.close();
    stdout.writeln('words -> $target');

    final heights = [for (final word in words) word.height]..sort();
    final lefts = [for (final word in words) word.left]..sort();
    final rights = [for (final word in words) word.right]..sort();
    stdout.writeln('words: ${words.length} on ${words.last.page + 1} page(s)');
    stdout.writeln('median word height: ${heights[heights.length ~/ 2]}');
    stdout.writeln('x range: ${lefts.first} .. ${rights.last}');

    // Which x the money-looking words sit at tells whether the price column
    // fraction is right for this sender.
    final moneyLefts = <int, int>{};
    for (final word in words) {
      if (RegExp(r'^[€]?\s*\d[\d.,\s]*[.,]\d{2}\s*(?:€|EUR)?$')
          .hasMatch(word.text)) {
        final bucket = (word.left / 10).round() * 10;
        moneyLefts[bucket] = (moneyLefts[bucket] ?? 0) + 1;
      }
    }
    final ranked = moneyLefts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    stdout.writeln('money-token x buckets (10pt, most frequent first):');
    for (final entry in ranked.take(10)) {
      stdout.writeln('  x=${entry.key}\t${entry.value} tokens');
    }

    final result = parseReceiptPdf(words);
    for (final candidate in result.candidates) {
      stdout.writeln(
        '  ${candidate.amountCents}\t'
        '${candidate.quantity ?? ''}\t'
        '${candidate.description}',
      );
    }

    final sum = result.candidates
        .fold<int>(0, (total, c) => total + (c.amountCents ?? 0));
    // Totals last: they are the point of the run and must not scroll away.
    final expected = result.expectedPositionSumCents;
    stdout.writeln('=== positions: ${result.candidates.length}');
    stdout.writeln('=== sum: $sum cents');
    stdout.writeln('=== printed total: ${result.printedTotalCents} cents');
    stdout.writeln('=== credits: ${result.creditCents} cents');
    stdout.writeln('=== expected position sum: $expected cents');
    stdout.writeln(
      '=== checksum: ${expected == null ? 'no total found' : (sum == expected ? 'MATCH' : 'MISMATCH by ${sum - expected}')}',
    );
  });
}
