import 'dart:typed_data';

import 'package:budget_view/features/transaction/import/pdf/ing_giro_parser.dart';
import 'package:budget_view/features/transaction/import/pdf/pdf_parser_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = IngGiroParser();

  test('identifies itself with a stable id', () {
    expect(parser.id, 'ing-giro-v1');
    expect(parser.displayName, 'ING Girokonto');
  });

  test('canParse returns 0.0 for bytes that are not a PDF', () async {
    final garbage = Uint8List.fromList(List.generate(512, (i) => i % 256));

    expect(await parser.canParse(garbage), 0.0);
  });

  test('canParse returns 0.0 for empty bytes instead of throwing', () async {
    expect(await parser.canParse(Uint8List(0)), 0.0);
  });

  test('the shipped registry exposes exactly the ING parser', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final registry = container.read(pdfParserRegistryProvider);

    expect(registry.all.map((p) => p.id), ['ing-giro-v1']);
  });
}
