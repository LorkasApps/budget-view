import 'dart:typed_data';

import 'parse_result.dart';

/// Contract every concrete bank-statement PDF parser implements.
///
/// Parsers are registered in PdfParserRegistry and picked per document by their
/// canParse confidence; the user may override the pick.
abstract interface class PdfParser {
  /// Stable and unique across all parsers, e.g. `dkb-giro-v1`.
  String get id;

  String get displayName;

  /// Confidence between 0.0 and 1.0 that this parser handles [bytes].
  Future<double> canParse(Uint8List bytes);

  Future<ParseResult> parse(Uint8List bytes);
}
