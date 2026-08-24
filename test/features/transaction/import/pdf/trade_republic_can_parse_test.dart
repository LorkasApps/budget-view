import 'dart:typed_data';

import 'package:budget_view/features/transaction/import/pdf/trade_republic_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = TradeRepublicParser();

  test('identifies itself with a stable id', () {
    expect(parser.id, 'trade-republic-cash-v1');
    expect(parser.displayName, 'Trade Republic Cashkonto');
  });

  test('canParse returns 0.0 for bytes that are not a PDF', () async {
    final garbage = Uint8List.fromList(List.generate(512, (i) => i % 256));

    expect(await parser.canParse(garbage), 0.0);
  });

  test('canParse returns 0.0 for empty bytes instead of throwing', () async {
    expect(await parser.canParse(Uint8List(0)), 0.0);
  });
}
