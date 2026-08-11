import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pdf_parser_registry.dart';

/// Starts empty; concrete parsers register themselves here.
final pdfParserRegistryProvider = Provider<PdfParserRegistry>((ref) {
  return PdfParserRegistry();
});
