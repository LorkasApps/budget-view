import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../data/imported_source.dart';
import '../data/imported_source_kind.dart';
import '../domain/import_providers.dart';

/// What every import left behind, and the way to drop it.
///
/// Deleting a row only silences the re-import warning for that document — the
/// bookings it produced stay, because the row holds counts and no reference to
/// them.
class ImportHistoryScreen extends ConsumerWidget {
  const ImportHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(importedSourcesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Import-Historie')),
      body: sourcesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (sources) {
          if (sources.isEmpty) {
            return const Center(child: Text('Noch keine Importe.'));
          }
          return ListView.separated(
            itemCount: sources.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) => _SourceTile(source: sources[i]),
          );
        },
      ),
    );
  }
}

class _SourceTile extends ConsumerWidget {
  const _SourceTile({required this.source});

  final ImportedSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(importedSourceRepositoryProvider);

    return Dismissible(
      key: ValueKey(source.uuid),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline),
      ),
      confirmDismiss: (_) async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Eintrag löschen?'),
            content: Text(
              '"${_sourceLabel(source)}" verschwindet aus der Historie, '
              'damit ein erneuter Import nicht mehr warnt. '
              'Die importierten Buchungen bleiben erhalten.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Löschen'),
              ),
            ],
          ),
        );
        if (ok ?? false) {
          await repo.delete(source.uuid);
        }
        return false; // the list updates reactively; don't drop the tile itself
      },
      child: ListTile(
        leading: Icon(switch (source.kind) {
          ImportedSourceKind.pdf => Icons.picture_as_pdf_outlined,
          ImportedSourceKind.photo => Icons.photo_camera_outlined,
          ImportedSourceKind.receiptPdf => Icons.receipt_long_outlined,
        }),
        title: Text(_sourceLabel(source)),
        subtitle: Text(_subtitle(source)),
        isThreeLine: source.note != null && source.note!.isNotEmpty,
      ),
    );
  }
}

/// PDF imports carry the picker's filename; captures have none, so the kind
/// stands in for it.
String _sourceLabel(ImportedSource source) =>
    source.filename.isNotEmpty ? source.filename : source.kind.label;

String _subtitle(ImportedSource source) {
  final parts = <String>[
    formatDateDe(source.importedAt),
    _count(source.transactionsProduced, 'Buchung', 'Buchungen'),
  ];
  if (source.lineItemsProduced > 0) {
    parts.add(_count(source.lineItemsProduced, 'Position', 'Positionen'));
  }
  final line = parts.join(' · ');
  final note = source.note;
  return note == null || note.isEmpty ? line : '$line\n$note';
}

String _count(int value, String singular, String plural) =>
    '$value ${value == 1 ? singular : plural}';
