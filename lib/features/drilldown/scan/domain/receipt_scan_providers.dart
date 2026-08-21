import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/file_selector_receipt_pdf_source.dart';
import '../data/heuristic_receipt_line_item_parser.dart';
import '../data/image_picker_receipt_image_source.dart';
import '../data/jpeg_receipt_image_preprocessor.dart';
import '../data/mlkit_ocr_service.dart';
import '../data/syncfusion_receipt_pdf_reader.dart';
import 'ocr_service.dart';
import 'receipt_document_source.dart';
import 'receipt_image_source.dart';
import 'receipt_line_item_parser.dart';
import 'receipt_pdf_reader.dart';
import 'receipt_scan_flow_controller.dart';

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

final receiptLineItemParserProvider = Provider<ReceiptLineItemParser>(
  (_) => const HeuristicReceiptLineItemParser(),
);

final receiptPdfSourceProvider = Provider<ReceiptPdfSource>(
  (_) => const FileSelectorReceiptPdfSource(),
);

final receiptPdfReaderProvider = Provider<ReceiptPdfReader>(
  (_) => const SyncfusionReceiptPdfReader(),
);

/// `autoDispose` on purpose: leaving the flow must drop the photo bytes.
final receiptScanFlowProvider = NotifierProvider.autoDispose<
    ReceiptScanFlowController, ReceiptScanFlowState>(
  ReceiptScanFlowController.new,
);
