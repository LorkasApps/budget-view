import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/ocr_service.dart';

/// Seam over the plugin. The native binding has no implementation in the test
/// VM, so the recognizer call is the one thing tests replace.
abstract interface class MlKitTextReader {
  Future<RecognizedText> read(String filePath);

  Future<void> close();
}

class TextRecognizerReader implements MlKitTextReader {
  TextRecognizerReader([TextRecognizer? recognizer])
      : _recognizer = recognizer ??
            TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  @override
  Future<RecognizedText> read(String filePath) =>
      _recognizer.processImage(InputImage.fromFilePath(filePath));

  @override
  Future<void> close() => _recognizer.close();
}

/// On-device OCR via ML Kit.
///
/// ML Kit refuses encoded images: `InputImage.fromBytes` wants raw NV21 plus a
/// rotation on Android, so the downscaled capture takes a detour through a temp
/// file this class owns and deletes again. Doing the conversion in Dart would
/// mean owning YUV *and* EXIF rotation, where a mistake reads as garbage text
/// instead of crashing.
class MlKitOcrService implements OcrService {
  MlKitOcrService(this._reader, {Future<Directory> Function()? cacheDirectory})
      : _cacheDirectory = cacheDirectory ?? getTemporaryDirectory;

  final MlKitTextReader _reader;
  final Future<Directory> Function() _cacheDirectory;

  @override
  Future<OcrResult> recognize(Uint8List bytes) async {
    final directory = await _cacheDirectory();
    final file = File(
      '${directory.path}/scan_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );

    try {
      await file.writeAsBytes(bytes, flush: true);
      return _toOcrResult(await _reader.read(file.path));
    } catch (error) {
      throw OcrEngineException('Texterkennung fehlgeschlagen: $error');
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  /// Releases the native recognizer. Wired to `ocrServiceProvider`'s dispose.
  Future<void> close() => _reader.close();
}

OcrResult _toOcrResult(RecognizedText recognized) => OcrResult(
      fullText: recognized.text,
      blocks: [
        for (final block in recognized.blocks)
          OcrBlock(
            text: block.text,
            boundingBox: block.boundingBox,
            lines: [
              for (final line in block.lines)
                OcrLine(
                  text: line.text,
                  boundingBox: line.boundingBox,
                  confidence: line.confidence,
                ),
            ],
          ),
      ],
    );
