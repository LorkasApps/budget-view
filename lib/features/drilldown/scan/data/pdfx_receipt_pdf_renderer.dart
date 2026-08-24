import 'dart:typed_data';

import 'package:pdfx/pdfx.dart';

import '../domain/receipt_pdf_renderer.dart';

/// Renders PDF pages with `pdfx`, which on Android goes through the OS's own
/// `android.graphics.pdf.PdfRenderer` — no pdfium in the APK.
///
/// Opens the document per call rather than holding it open: a scanned receipt has
/// a handful of pages, and a renderer that owns a native handle across awaits
/// would need a lifecycle the flow does not have.
class PdfxReceiptPdfRenderer implements ReceiptPdfRenderer {
  const PdfxReceiptPdfRenderer();

  @override
  Future<int> pageCount(Uint8List bytes) async {
    final document = await PdfDocument.openData(bytes);
    try {
      return document.pagesCount;
    } finally {
      await document.close();
    }
  }

  @override
  Future<Uint8List> renderPage(
    Uint8List bytes, {
    required int pageNumber,
    required int longestEdge,
  }) async {
    final document = await PdfDocument.openData(bytes);
    try {
      final page = await document.getPage(pageNumber);
      try {
        final longest = page.width > page.height ? page.width : page.height;
        final scale = longest == 0 ? 1.0 : longestEdge / longest;
        final image = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: PdfPageImageFormat.png,
        );
        final rendered = image?.bytes;
        if (rendered == null) {
          throw StateError('Seite $pageNumber konnte nicht gerendert werden.');
        }
        return rendered;
      } finally {
        await page.close();
      }
    } finally {
      await document.close();
    }
  }
}
