import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/image_picker_receipt_image_source.dart';
import '../data/jpeg_receipt_image_preprocessor.dart';
import '../data/mlkit_ocr_service.dart';
import 'ocr_service.dart';
import 'photo_scan_flow_controller.dart';
import 'receipt_image_source.dart';
import 'receipt_line_item_parser.dart';

final receiptImageSourceProvider = Provider<ReceiptImageSource>(
  (_) => ImagePickerReceiptImageSource(),
);

final receiptImagePreprocessorProvider = Provider<ReceiptImagePreprocessor>(
  (_) => const JpegReceiptImagePreprocessor(),
);

final ocrServiceProvider = Provider<OcrService>((ref) {
  // One native recognizer for the app's lifetime instead of one per photo,
  // which is what ML Kit recommends; released with the provider.
  final service = MlKitOcrService(TextRecognizerReader());
  ref.onDispose(service.close);
  return service;
});

/// Replaced by ticket 018's heuristics.
final receiptLineItemParserProvider = Provider<ReceiptLineItemParser>(
  (_) => const NoReceiptLineItemParser(),
);

/// `autoDispose` on purpose: leaving the flow must drop the photo bytes.
final photoScanFlowProvider =
    NotifierProvider.autoDispose<PhotoScanFlowController, PhotoScanFlowState>(
  PhotoScanFlowController.new,
);
