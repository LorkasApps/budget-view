import 'dart:ui';

import 'package:budget_view/features/drilldown/scan/domain/ocr_page_stack.dart';
import 'package:budget_view/features/drilldown/scan/domain/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

OcrResult _page(String text, {required double top}) => OcrResult(
  fullText: text,
  blocks: [
    OcrBlock(
      text: text,
      boundingBox: Rect.fromLTWH(0, top, 300, 20),
      lines: [
        OcrLine(text: text, boundingBox: Rect.fromLTWH(0, top, 300, 20)),
      ],
    ),
  ],
);

void main() {
  test('a single page is handed back untouched', () {
    final page = _page('Milch 1,19', top: 100);

    expect(stackOcrPages([page]), same(page));
  });

  test('later pages are pushed below the ones before them', () {
    final stacked = stackOcrPages([
      _page('Seite eins', top: 100),
      _page('Seite zwei', top: 100),
    ]);

    final tops = [
      for (final block in stacked.blocks) block.boundingBox.top,
    ];
    expect(tops.first, 100);
    // Page two started at 100 as well; it now sits below page one's bottom plus
    // the gap, so no row grouping can pair rows across the seam.
    expect(tops.last, greaterThan(300));
    expect(stacked.blocks.last.lines.single.boundingBox.top, tops.last);
    expect(stacked.fullText, 'Seite eins\nSeite zwei');
  });

  test('an empty page shifts nothing but the gap', () {
    final stacked = stackOcrPages([
      const OcrResult(),
      _page('Seite zwei', top: 50),
    ]);

    expect(stacked.blocks, hasLength(1));
    expect(stacked.blocks.single.boundingBox.top, 250);
  });
}
