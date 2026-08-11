import 'dart:typed_data';

import 'package:budget_view/features/transaction/import/pdf/parse_result.dart';
import 'package:budget_view/features/transaction/import/pdf/pdf_parser.dart';
import 'package:budget_view/features/transaction/import/pdf/pdf_parser_registry.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeParser implements PdfParser {
  _FakeParser(
    this.id,
    this._confidence, {
    this.delay = Duration.zero,
    this.throwOnCanParse = false,
  });

  @override
  final String id;

  final double _confidence;
  final Duration delay;
  final bool throwOnCanParse;

  @override
  String get displayName => 'Fake $id';

  @override
  Future<double> canParse(Uint8List bytes) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (throwOnCanParse) throw StateError('canParse exploded');
    return _confidence;
  }

  @override
  Future<ParseResult> parse(Uint8List bytes) async =>
      const ParseResult(transactions: []);
}

void main() {
  final bytes = Uint8List(0);

  test('rank orders registered parsers by confidence, highest first', () async {
    final registry = PdfParserRegistry()
      ..register(_FakeParser('low', 0.2))
      ..register(_FakeParser('high', 0.9))
      ..register(_FakeParser('mid', 0.5));

    final ranked = await registry.rank(bytes);

    expect(ranked.map((r) => r.parser.id), ['high', 'mid', 'low']);
    expect(ranked.first.confidence, 0.9);
  });

  test('rank skips a parser whose canParse throws', () async {
    final registry = PdfParserRegistry()
      ..register(_FakeParser('ok', 0.4))
      ..register(_FakeParser('broken', 0.9, throwOnCanParse: true));

    final ranked = await registry.rank(bytes);

    expect(ranked.map((r) => r.parser.id), ['ok']);
  });

  test('rank skips a parser that exceeds the canParse timeout', () async {
    final registry =
        PdfParserRegistry(canParseTimeout: const Duration(milliseconds: 20))
          ..register(_FakeParser('fast', 0.3))
          ..register(
            _FakeParser(
              'slow',
              0.99,
              delay: const Duration(milliseconds: 300),
            ),
          );

    final ranked = await registry.rank(bytes);

    expect(ranked.map((r) => r.parser.id), ['fast']);
  });

  test('rank clamps confidence into 0.0..1.0', () async {
    final registry = PdfParserRegistry()
      ..register(_FakeParser('over', 4.2))
      ..register(_FakeParser('under', -1.0));

    final ranked = await registry.rank(bytes);

    expect(ranked.map((r) => r.confidence), [1.0, 0.0]);
  });

  test('rank on an empty registry yields an empty list', () async {
    expect(await PdfParserRegistry().rank(bytes), isEmpty);
  });

  test('register rejects a duplicate parser id', () {
    final registry = PdfParserRegistry()..register(_FakeParser('dup', 0.5));

    expect(
      () => registry.register(_FakeParser('dup', 0.7)),
      throwsArgumentError,
    );
  });

  test('all exposes registered parsers and cannot be mutated', () {
    final registry = PdfParserRegistry()..register(_FakeParser('a', 0.5));

    expect(registry.all.single.id, 'a');
    expect(
      () => registry.all.add(_FakeParser('b', 0.5)),
      throwsUnsupportedError,
    );
  });
}
