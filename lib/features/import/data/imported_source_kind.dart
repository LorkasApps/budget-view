/// Where an import came from.
///
/// `pdf` means a bank statement; a receipt that arrived as a PDF is
/// [receiptPdf], because the import history has to tell the two apart. Appended
/// at the end on purpose: Isar stores `@enumerated` by index, so existing rows
/// keep their meaning and no schema bump is needed.
enum ImportedSourceKind { pdf, photo, receiptPdf }

extension ImportedSourceKindLabel on ImportedSourceKind {
  String get label => switch (this) {
        ImportedSourceKind.pdf => 'PDF',
        ImportedSourceKind.photo => 'Foto',
        ImportedSourceKind.receiptPdf => 'PDF-Beleg',
      };
}
