import 'package:flutter/material.dart';

import '../domain/receipt_document_source.dart';

/// Camera, gallery or a PDF document. Null when the user dismisses the sheet.
Future<ReceiptSource?> showScanSourceSheet(BuildContext context) =>
    showModalBottomSheet<ReceiptSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(sheetContext, ReceiptSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galerie'),
              onTap: () => Navigator.pop(sheetContext, ReceiptSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF-Beleg'),
              subtitle: const Text('Rechnung oder Bon als Datei'),
              onTap: () => Navigator.pop(sheetContext, ReceiptSource.pdf),
            ),
          ],
        ),
      ),
    );
