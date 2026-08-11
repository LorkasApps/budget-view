import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ing_giro_parser.dart';
import 'pdf_parser_registry.dart';

/// Every shipped parser is registered here. Registration lives in the provider
/// rather than in app startup so tests can assert the real parser set without
/// booting the widget tree.
final pdfParserRegistryProvider = Provider<PdfParserRegistry>((ref) {
  return PdfParserRegistry()..register(const IngGiroParser());
});
