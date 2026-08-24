import 'dart:typed_data';

/// Rasterises the pages of a PDF that carries no text layer, so a scanned receipt
/// can travel the same road as a photographed one (ticket 044).
///
/// Behind an interface for the same reason as [ReceiptPdfReader]: the renderer is
/// native, and the flow tests have to run without it.
abstract interface class ReceiptPdfRenderer {
  /// Without rendering anything — the flow asks before a long run.
  Future<int> pageCount(Uint8List bytes);

  /// One page as encoded image bytes, scaled so its longest edge is
  /// [longestEdge]. [pageNumber] is one-based, as PDF pages are.
  Future<Uint8List> renderPage(
    Uint8List bytes, {
    required int pageNumber,
    required int longestEdge,
  });
}
