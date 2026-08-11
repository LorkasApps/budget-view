import 'dart:typed_data';

import 'pdf_parser.dart';

typedef PdfParserRanking = ({PdfParser parser, double confidence});

/// Holds the available PDF parsers and ranks them per document.
class PdfParserRegistry {
  PdfParserRegistry({this.canParseTimeout = const Duration(seconds: 5)});

  final Duration canParseTimeout;

  final Map<String, PdfParser> _parsers = {};

  void register(PdfParser parser) {
    if (_parsers.containsKey(parser.id)) {
      throw ArgumentError.value(
        parser.id,
        'parser.id',
        'a parser with this id is already registered',
      );
    }
    _parsers[parser.id] = parser;
  }

  List<PdfParser> get all => List.unmodifiable(_parsers.values);

  /// Confidence of every registered parser, highest first. A parser that throws
  /// or exceeds [canParseTimeout] is skipped rather than failing the whole rank,
  /// so one broken plug-in cannot block the import.
  Future<List<PdfParserRanking>> rank(Uint8List bytes) async {
    final parsers = _parsers.values.toList(growable: false);
    final scores = await Future.wait(
      parsers.map((parser) => _confidence(parser, bytes)),
    );

    final ranked = <PdfParserRanking>[];
    for (var i = 0; i < parsers.length; i++) {
      final score = scores[i];
      if (score != null) {
        ranked.add((parser: parsers[i], confidence: score));
      }
    }
    ranked.sort((a, b) => b.confidence.compareTo(a.confidence));
    return ranked;
  }

  Future<double?> _confidence(PdfParser parser, Uint8List bytes) async {
    try {
      final score = await parser.canParse(bytes).timeout(canParseTimeout);
      if (score.isNaN) return null;
      return score.clamp(0.0, 1.0).toDouble();
    } catch (_) {
      return null;
    }
  }
}
