import 'package:flutter/material.dart';

import '../domain/receipt_image_source.dart';

/// Camera or gallery. Null when the user dismisses the sheet.
Future<ScanSource?> showScanSourceSheet(BuildContext context) =>
    showModalBottomSheet<ScanSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(sheetContext, ScanSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galerie'),
              onTap: () => Navigator.pop(sheetContext, ScanSource.gallery),
            ),
          ],
        ),
      ),
    );
