import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
import '../../../../core/money/money.dart';
import '../../data/transaction.dart';
import '../candidate_conversion.dart';
import '../pdf/pdf_parser.dart';
import '../pdf/pdf_parser_providers.dart';
import '../pdf/pdf_parser_registry.dart';

/// Import flow: pick a statement PDF, let the registry rank the parsers,
/// confirm one, read it out. Persisting the result is not wired up yet.
class PdfImportScreen extends ConsumerStatefulWidget {
  const PdfImportScreen({super.key, required this.accountUuid});

  final String accountUuid;

  @override
  ConsumerState<PdfImportScreen> createState() => _PdfImportScreenState();
}

class _PdfImportScreenState extends ConsumerState<PdfImportScreen> {
  Uint8List? _bytes;
  String? _fileName;
  List<PdfParserRanking> _ranking = const [];
  PdfParser? _selected;
  List<Transaction> _converted = const [];
  List<String> _warnings = const [];
  bool _busy = false;
  String? _error;

  Future<void> _pickFile() async {
    const pdfGroup = XTypeGroup(
      label: 'PDF',
      extensions: ['pdf'],
      mimeTypes: ['application/pdf'],
    );
    final file = await openFile(acceptedTypeGroups: const [pdfGroup]);
    if (file == null) return;

    setState(() {
      _busy = true;
      _error = null;
      _converted = const [];
      _warnings = const [];
    });
    try {
      final bytes = await file.readAsBytes();
      final ranking = await ref.read(pdfParserRegistryProvider).rank(bytes);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _fileName = file.name;
        _ranking = ranking;
        _selected = ranking.isEmpty ? null : ranking.first.parser;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Datei konnte nicht gelesen werden: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runParse() async {
    final parser = _selected;
    final bytes = _bytes;
    if (parser == null || bytes == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await parser.parse(bytes);
      if (!mounted) return;
      setState(() {
        _converted = result.transactions
            .map(
              (c) => candidateToTransaction(c, accountUuid: widget.accountUuid),
            )
            .toList();
        _warnings = result.warnings;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Parsen fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('PDF importieren')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : _pickFile,
            icon: const Icon(Icons.attach_file),
            label: const Text('PDF auswählen'),
          ),
          if (_fileName != null) ...[
            const SizedBox(height: 12),
            Text(_fileName!, style: theme.textTheme.bodyMedium),
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (!_busy && _fileName != null && _ranking.isEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Kein Parser kann diese Datei lesen — es ist noch keiner '
              'registriert.',
            ),
          ],
          if (_ranking.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Parser', style: theme.textTheme.titleMedium),
            for (final match in _ranking)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  match.parser.id == _selected?.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(match.parser.displayName),
                subtitle: Text(
                  '${(match.confidence * 100).round()} % Konfidenz',
                ),
                onTap: _busy
                    ? null
                    : () => setState(() => _selected = match.parser),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy || _selected == null ? null : _runParse,
              child: const Text('Auslesen'),
            ),
          ],
          if (_warnings.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Hinweise', style: theme.textTheme.titleMedium),
            for (final warning in _warnings)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $warning', style: theme.textTheme.bodySmall),
              ),
          ],
          if (_converted.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              '${_converted.length} Buchungen erkannt',
              style: theme.textTheme.titleMedium,
            ),
            Text(
              'Speichern ist noch nicht angebunden.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final transaction in _converted)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Text(
                  formatDateCompactDe(transaction.bookingDate),
                  style: theme.textTheme.bodySmall,
                ),
                title: Text(transaction.description),
                trailing: Text(formatCentsEur(transaction.amountCents)),
              ),
          ],
        ],
      ),
    );
  }
}
