import 'package:file_selector/file_selector.dart';

import '../domain/receipt_document_source.dart';

/// Picks a receipt PDF through the platform file dialog, the same package the
/// statement import uses.
class FileSelectorReceiptPdfSource implements ReceiptPdfSource {
  const FileSelectorReceiptPdfSource();

  @override
  Future<PickedReceiptDocument?> pick() async {
    const pdfGroup = XTypeGroup(
      label: 'PDF',
      extensions: ['pdf'],
      mimeTypes: ['application/pdf'],
    );

    final file = await openFile(acceptedTypeGroups: const [pdfGroup]);
    if (file == null) return null;

    return PickedReceiptDocument(
      bytes: await file.readAsBytes(),
      filename: file.name,
    );
  }
}
