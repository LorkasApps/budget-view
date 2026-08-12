import 'dart:typed_data';

import 'package:budget_view/features/import/domain/content_hash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bytes = Uint8List.fromList(List.generate(256, (i) => i));

  test('is a 64-char hex digest and deterministic', () {
    final hash = computeContentHash(bytes);

    expect(hash, hasLength(64));
    expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(hash, computeContentHash(Uint8List.fromList(bytes)));
  });

  test('a single changed byte changes the digest', () {
    final altered = Uint8List.fromList(bytes)..[128] = 0;

    expect(computeContentHash(altered), isNot(computeContentHash(bytes)));
  });

  test('empty input still hashes', () {
    expect(computeContentHash(Uint8List(0)), hasLength(64));
  });
}
