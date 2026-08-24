import 'ocr_service.dart';

/// Vertical gap inserted between two stacked pages, in pixels of the recognised
/// image. Far wider than any row tolerance, so no row grouping spans the seam.
const _pageGap = 200.0;

/// Stacks the recognised pages of one document into a single [OcrResult].
///
/// Every page's coordinates start at zero, so merging them as they are would
/// interleave the rows of different pages and pair a description on page two with
/// a price on page one. Each page after the first is therefore shifted below its
/// predecessor. One result also means one parse, which is what keeps the printed
/// total, the credits and the plausibility bound working across a document whose
/// total sits on the last page.
OcrResult stackOcrPages(List<OcrResult> pages) {
  if (pages.length == 1) return pages.first;

  final blocks = <OcrBlock>[];
  var offset = 0.0;
  for (final page in pages) {
    var pageBottom = 0.0;
    for (final block in page.blocks) {
      blocks.add(
        OcrBlock(
          text: block.text,
          boundingBox: block.boundingBox.translate(0, offset),
          lines: [
            for (final line in block.lines)
              OcrLine(
                text: line.text,
                boundingBox: line.boundingBox.translate(0, offset),
                confidence: line.confidence,
              ),
          ],
        ),
      );
      if (block.boundingBox.bottom > pageBottom) {
        pageBottom = block.boundingBox.bottom;
      }
      for (final line in block.lines) {
        if (line.boundingBox.bottom > pageBottom) {
          pageBottom = line.boundingBox.bottom;
        }
      }
    }
    offset += pageBottom + _pageGap;
  }

  return OcrResult(
    fullText: pages.map((page) => page.fullText).join('\n'),
    blocks: blocks,
  );
}
