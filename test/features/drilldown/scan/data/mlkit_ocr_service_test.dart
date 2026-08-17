import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:budget_view/features/drilldown/scan/data/mlkit_ocr_service.dart';
import 'package:budget_view/features/drilldown/scan/domain/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Stands in for the plugin: the native binding has no implementation in the
/// test VM. Records what the service handed it, so the temp-file detour is
/// observable.
class _FakeReader implements MlKitTextReader {
  _FakeReader({this.result, this.error});

  final RecognizedText? result;
  final Object? error;

  final readPaths = <String>[];
  final bytesSeen = <Uint8List>[];
  var closed = false;

  @override
  Future<RecognizedText> read(String filePath) async {
    readPaths.add(filePath);
    final file = File(filePath);
    if (file.existsSync()) bytesSeen.add(file.readAsBytesSync());
    if (error != null) throw error!;
    return result!;
  }

  @override
  Future<void> close() async => closed = true;
}

TextLine _line(String text, Rect box, {double? confidence}) => TextLine(
      text: text,
      elements: const [],
      boundingBox: box,
      recognizedLanguages: const ['de'],
      cornerPoints: const <Point<int>>[],
      confidence: confidence,
      angle: null,
    );

TextBlock _block(String text, Rect box, List<TextLine> lines) => TextBlock(
      text: text,
      lines: lines,
      boundingBox: box,
      recognizedLanguages: const ['de'],
      cornerPoints: const <Point<int>>[],
    );

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('budgetview_ocr_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  MlKitOcrService serviceWith(_FakeReader reader) =>
      MlKitOcrService(reader, cacheDirectory: () async => tempDir);

  final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

  test('maps blocks, lines, boxes and confidence', () async {
    final reader = _FakeReader(
      result: RecognizedText(
        text: 'Käse 2,49\nÖl 3,99',
        blocks: [
          _block(
            'Käse 2,49\nÖl 3,99',
            const Rect.fromLTRB(10, 20, 300, 80),
            [
              _line('Käse 2,49', const Rect.fromLTRB(10, 20, 300, 45),
                  confidence: 0.91),
              _line('Öl 3,99', const Rect.fromLTRB(10, 50, 290, 80)),
            ],
          ),
        ],
      ),
    );

    final result = await serviceWith(reader).recognize(bytes);

    expect(result.fullText, 'Käse 2,49\nÖl 3,99');
    expect(result.isEmpty, isFalse);
    expect(result.blocks, hasLength(1));
    expect(
      result.blocks.single.boundingBox,
      const Rect.fromLTRB(10, 20, 300, 80),
    );
    expect(result.blocks.single.lines, hasLength(2));
    expect(result.blocks.single.lines.first.text, 'Käse 2,49');
    expect(result.blocks.single.lines.first.confidence, 0.91);
    expect(
      result.blocks.single.lines.last.boundingBox,
      const Rect.fromLTRB(10, 50, 290, 80),
    );
    expect(result.blocks.single.lines.last.confidence, isNull);
  });

  test('hands the recognizer a file holding the given bytes', () async {
    final reader = _FakeReader(
      result: RecognizedText(text: '', blocks: const []),
    );

    await serviceWith(reader).recognize(bytes);

    expect(reader.readPaths, hasLength(1));
    expect(reader.readPaths.single, startsWith(tempDir.path));
    expect(reader.bytesSeen.single, bytes);
  });

  test('an empty result travels on instead of throwing', () async {
    final reader = _FakeReader(
      result: RecognizedText(text: '', blocks: const []),
    );

    final result = await serviceWith(reader).recognize(bytes);

    expect(result.isEmpty, isTrue);
    expect(result.fullText, isEmpty);
  });

  test('engine failure becomes OcrEngineException', () async {
    final reader = _FakeReader(error: StateError('ML Kit kaputt'));

    await expectLater(
      serviceWith(reader).recognize(bytes),
      throwsA(
        isA<OcrEngineException>().having(
          (e) => e.message,
          'message',
          contains('Texterkennung fehlgeschlagen'),
        ),
      ),
    );
  });

  test('temp file is gone after a successful recognition', () async {
    final reader = _FakeReader(
      result: RecognizedText(text: 'x', blocks: const []),
    );

    await serviceWith(reader).recognize(bytes);

    expect(tempDir.listSync(), isEmpty);
  });

  test('temp file is gone even when the recognizer throws', () async {
    final reader = _FakeReader(error: StateError('ML Kit kaputt'));

    await expectLater(
      serviceWith(reader).recognize(bytes),
      throwsA(isA<OcrEngineException>()),
    );
    expect(tempDir.listSync(), isEmpty);
  });

  test('close releases the reader', () async {
    final reader = _FakeReader(
      result: RecognizedText(text: '', blocks: const []),
    );

    await serviceWith(reader).close();

    expect(reader.closed, isTrue);
  });
}
