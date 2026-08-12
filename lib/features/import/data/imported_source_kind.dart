enum ImportedSourceKind { pdf, photo }

extension ImportedSourceKindLabel on ImportedSourceKind {
  String get label => switch (this) {
        ImportedSourceKind.pdf => 'PDF',
        ImportedSourceKind.photo => 'Foto',
      };
}
