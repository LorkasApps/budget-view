import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/date_format.dart';
import '../../../../core/money/money.dart';
import '../../../account/data/account.dart';
import '../../../account/domain/account_providers.dart';
import '../../../category/domain/category_providers.dart';
import '../../../category/presentation/category_chip.dart';
import '../../../category/presentation/category_picker.dart';
import '../../../import/data/imported_source.dart';
import '../../../tagging/domain/tagging_suggest_service.dart';
import '../../../tagging/presentation/suggestion_sheet.dart';
import '../../data/transaction.dart';
import '../domain/import_flow_controller.dart';

/// Import flow: pick a statement PDF, confirm the detected parser, curate the
/// parsed rows, then persist them onto an account.
class PdfImportScreen extends ConsumerStatefulWidget {
  const PdfImportScreen({super.key, required this.accountUuid});

  final String accountUuid;

  @override
  ConsumerState<PdfImportScreen> createState() => _PdfImportScreenState();
}

class _PdfImportScreenState extends ConsumerState<PdfImportScreen> {
  String _pickError = '';

  @override
  void initState() {
    super.initState();
    // Duplicate scoping needs the target account before anything is parsed.
    Future.microtask(
      () => ref
          .read(importFlowProvider.notifier)
          .setTargetAccount(widget.accountUuid),
    );
  }

  Future<void> _pickFile() async {
    const pdfGroup = XTypeGroup(
      label: 'PDF',
      extensions: ['pdf'],
      mimeTypes: ['application/pdf'],
    );

    final file = await openFile(acceptedTypeGroups: const [pdfGroup]);
    if (file == null) return;

    setState(() => _pickError = '');
    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      await ref
          .read(importFlowProvider.notifier)
          .loadDocument(bytes, fileName: file.name);
    } catch (e) {
      if (mounted) {
        setState(() => _pickError = 'Datei konnte nicht gelesen werden: $e');
      }
      return;
    }

    if (!mounted) return;
    final matches = ref.read(importFlowProvider).documentMatches;
    if (matches.isNotEmpty) await _confirmReimport(matches);
  }

  Future<void> _confirmReimport(List<ImportedSource> matches) async {
    final previous = matches.first;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Datei schon importiert'),
        content: Text(
          'Diese Datei wurde am ${formatDateDe(previous.importedAt)} bereits '
          'importiert und hat damals ${previous.transactionsProduced} '
          'Buchungen erzeugt'
          '${matches.length > 1 ? ' (insgesamt ${matches.length} Importe)' : ''}'
          '.\n\nTrotzdem fortfahren?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Fortfahren'),
          ),
        ],
      ),
    );

    // Cancelling leaves the flow: popping disposes the controller, which drops
    // the bytes.
    if (proceed != true && mounted) Navigator.of(context).pop();
  }

  Future<void> _showRowMatches(int index) async {
    final state = ref.read(importFlowProvider);
    final matches = state.rowMatches[index] ?? const <Transaction>[];
    final intraBatch = state.intraBatchDuplicates.contains(index);

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Möglicher Doppel-Eintrag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (intraBatch)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Kommt in diesem Dokument mehrfach vor.'),
              ),
            if (matches.isNotEmpty) ...[
              const Text('Bereits gebucht:'),
              const SizedBox(height: 8),
              for (final match in matches)
                Text(
                  '${formatDateCompactDe(match.bookingDate)} · '
                  '${formatCentsEur(match.amountCents)} · ${match.description}',
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  Future<void> _editRow(int index, ImportRow row) async {
    final suggestions =
        ref.read(importFlowProvider).rowSuggestions[index] ??
            const <CategorySuggestion>[];
    final edited = await showDialog<_RowEdit>(
      context: context,
      builder: (_) => _RowEditDialog(
        row: row,
        suggestionHitCount:
            row.categorySuggested && suggestions.isNotEmpty
                ? suggestions.first.hitCount
                : null,
      ),
    );
    if (edited == null) return;

    final notifier = ref.read(importFlowProvider.notifier);
    await notifier.editRow(
      index,
      bookingDate: edited.row.bookingDate,
      amountCents: edited.row.amountCents,
      description: edited.row.description,
      counterparty: edited.row.counterparty,
    );
    // Routed through the same call the row chip uses, so an override from the
    // dialog drops the suggestion provenance exactly as one from the row does.
    if (edited.categoryChanged) {
      notifier.setRowCategory(index, edited.categoryUuid);
    }
  }

  Future<void> _pickRowCategory(int index, ImportRow row) async {
    final pick = await pickCategory(
      context,
      selected: row.categoryUuid,
      allowNone: true,
    );
    if (pick == null) return;
    ref.read(importFlowProvider.notifier).setRowCategory(index, pick.uuid);
  }

  /// An alternative is an override, exactly as in the booking form: the row
  /// loses its suggestion provenance so the learn hook may raise that rule.
  Future<void> _chooseRowAlternative(int index) async {
    final state = ref.read(importFlowProvider);
    final suggestions =
        state.rowSuggestions[index] ?? const <CategorySuggestion>[];
    final picked = await pickSuggestion(
      context,
      suggestions,
      selectedCategoryUuid: state.rows[index].categoryUuid,
    );
    if (picked == null) return;
    ref
        .read(importFlowProvider.notifier)
        .setRowCategory(index, picked.categoryUuid);
  }

  Future<void> _pickCategoryForAll() async {
    final pick = await pickCategory(context, allowNone: true);
    if (pick == null) return;
    ref.read(importFlowProvider.notifier).setCategoryForAll(pick.uuid);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importFlowProvider);
    final theme = Theme.of(context);
    final summary = state.summary;

    return Scaffold(
      appBar: AppBar(title: const Text('PDF importieren')),
      body: summary != null
          ? _ImportSummary(summary: summary)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FilledButton.icon(
                  onPressed: state.busy ? null : _pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('PDF auswählen'),
                ),
                if (state.fileName != null) ...[
                  const SizedBox(height: 12),
                  Text(state.fileName!, style: theme.textTheme.bodyMedium),
                ],
                if (state.busy) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                ],
                for (final message in [_pickError, state.error])
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      message,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                if (!state.busy &&
                    state.hasDocument &&
                    state.ranking.isEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Kein Parser erkennt diese Datei.'),
                ],
                if (state.ranking.isNotEmpty && state.rows.isEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Parser', style: theme.textTheme.titleMedium),
                  for (final match in state.ranking)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        match.parser.id == state.selectedParserId
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                      ),
                      title: Text(match.parser.displayName),
                      subtitle: Text(
                        '${(match.confidence * 100).round()} % Konfidenz',
                      ),
                      onTap: state.busy
                          ? null
                          : () => ref
                              .read(importFlowProvider.notifier)
                              .selectParser(match.parser.id),
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: state.busy || state.selectedParserId == null
                        ? null
                        : () => ref
                            .read(importFlowProvider.notifier)
                            .parseDocument(),
                    child: const Text('Auslesen'),
                  ),
                ],
                if (state.rows.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${state.newCount} neu / '
                          '${state.suspiciousCount} mögliche Duplikate',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: state.busy ? null : _pickCategoryForAll,
                        icon: const Icon(Icons.label_outline),
                        label: const Text('Für alle'),
                      ),
                    ],
                  ),
                  Text(
                    '${state.includedCount} von ${state.rows.length} ausgewählt',
                    style: theme.textTheme.bodySmall,
                  ),
                  for (var index = 0; index < state.rows.length; index++)
                    _RowTile(
                      row: state.rows[index],
                      enabled: !state.busy,
                      suspicious: state.isSuspicious(index),
                      suggestions:
                          state.rowSuggestions[index] ?? const [],
                      onShowAlternatives: () => _chooseRowAlternative(index),
                      onToggle: () => ref
                          .read(importFlowProvider.notifier)
                          .toggleRow(index),
                      onEdit: () => _editRow(index, state.rows[index]),
                      onPickCategory: () =>
                          _pickRowCategory(index, state.rows[index]),
                      onShowMatches: () => _showRowMatches(index),
                    ),
                ],
                if (state.warnings.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Hinweise', style: theme.textTheme.titleMedium),
                  for (final warning in state.warnings)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '• $warning',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
                if (state.rows.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _AccountPicker(
                    selected: state.targetAccountUuid,
                    enabled: !state.busy,
                    onChanged: (uuid) {
                      if (uuid != null) {
                        ref
                            .read(importFlowProvider.notifier)
                            .setTargetAccount(uuid);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: state.busy ||
                            state.includedCount == 0 ||
                            state.targetAccountUuid == null
                        ? null
                        : () => ref.read(importFlowProvider.notifier).persist(),
                    child: Text('${state.includedCount} Buchungen importieren'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.row,
    required this.enabled,
    required this.suspicious,
    required this.suggestions,
    required this.onToggle,
    required this.onEdit,
    required this.onPickCategory,
    required this.onShowAlternatives,
    required this.onShowMatches,
  });

  final ImportRow row;
  final bool enabled;
  final bool suspicious;
  final List<CategorySuggestion> suggestions;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onPickCategory;
  final VoidCallback onShowAlternatives;
  final VoidCallback onShowMatches;

  int get _hitCount {
    for (final suggestion in suggestions) {
      if (suggestion.categoryUuid == row.categoryUuid) {
        return suggestion.hitCount;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpense = row.amountCents < 0;

    return CheckboxListTile(
      value: row.included,
      onChanged: enabled ? (_) => onToggle() : null,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: Text(
        row.description,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            CategoryChip(
              categoryUuid: row.categoryUuid,
              onTap: enabled ? onPickCategory : null,
            ),
            // Marks the category as the machine's guess and opens the
            // runners-up — the chip stays the way to the full tree.
            if (row.categorySuggested) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: enabled && suggestions.length > 1
                    ? onShowAlternatives
                    : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: 14,
                      color: theme.colorScheme.tertiary,
                    ),
                    Text(
                      '$_hitCount×',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${formatDateCompactDe(row.bookingDate)}'
                '${row.counterparty.isEmpty ? '' : ' · ${row.counterparty}'}',
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
      secondary: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (suspicious)
            IconButton(
              tooltip: 'Möglicher Doppel-Eintrag',
              icon: Icon(
                Icons.copy_all_outlined,
                color: theme.colorScheme.error,
              ),
              onPressed: onShowMatches,
            ),
          Text(
            formatCentsEur(row.amountCents),
            style: theme.textTheme.bodyMedium?.copyWith(
              color:
                  isExpense ? theme.colorScheme.error : Colors.green.shade700,
            ),
          ),
          IconButton(
            tooltip: 'Zeile bearbeiten',
            icon: const Icon(Icons.edit_outlined),
            onPressed: enabled ? onEdit : null,
          ),
        ],
      ),
    );
  }
}

class _AccountPicker extends ConsumerWidget {
  const _AccountPicker({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final String? selected;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider(false));

    return accountsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Konten nicht verfügbar: $e'),
      data: (accounts) => DropdownButtonFormField<String>(
        initialValue: selected,
        decoration: const InputDecoration(labelText: 'Zielkonto'),
        items: [
          for (final Account account in accounts)
            DropdownMenuItem(value: account.uuid, child: Text(account.name)),
        ],
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

class _ImportSummary extends StatelessWidget {
  const _ImportSummary({required this.summary});

  final ImportSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Import abgeschlossen', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Text('${summary.imported} importiert'),
          Text('${summary.skipped} übersprungen'),
          Text('${summary.warnings} Hinweise'),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fertig'),
          ),
        ],
      ),
    );
  }
}

/// What the edit dialog hands back. The category travels separately because it
/// is applied through `setRowCategory`, not through `editRow`.
typedef _RowEdit = ({ImportRow row, bool categoryChanged, String? categoryUuid});

class _RowEditDialog extends ConsumerStatefulWidget {
  const _RowEditDialog({required this.row, this.suggestionHitCount});

  final ImportRow row;

  /// Set when the row's category came from a learned rule — the count is what
  /// makes visible *why* this category is here before it gets replaced.
  final int? suggestionHitCount;

  @override
  ConsumerState<_RowEditDialog> createState() => _RowEditDialogState();
}

class _RowEditDialogState extends ConsumerState<_RowEditDialog> {
  late final TextEditingController _amount;
  late final TextEditingController _description;
  late final TextEditingController _counterparty;
  late DateTime _bookingDate;
  late bool _isExpense;
  late String? _categoryUuid;

  @override
  void initState() {
    super.initState();
    final row = widget.row;
    _bookingDate = row.bookingDate;
    _categoryUuid = row.categoryUuid;
    _isExpense = row.amountCents < 0;
    _amount = TextEditingController(
      text: (row.amountCents.abs() / 100).toStringAsFixed(2).replaceAll(
            '.',
            ',',
          ),
    );
    _description = TextEditingController(text: row.description);
    _counterparty = TextEditingController(text: row.counterparty);
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _counterparty.dispose();
    super.dispose();
  }

  int? _parsedCents() {
    final magnitude = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    if (magnitude == null || magnitude == 0) return null;
    final cents = (magnitude.abs() * 100).round();
    return _isExpense ? -cents : cents;
  }

  /// Resolved through the archived-inclusive list, so a row pointing at an
  /// archived category still shows its name instead of nothing.
  String _categoryName() {
    final uuid = _categoryUuid;
    if (uuid == null) return 'Keine Kategorie';
    final categories = ref.watch(categoriesProvider(true)).valueOrNull;
    for (final category in categories ?? const []) {
      if (category.uuid == uuid) return category.name;
    }
    return 'Kategorie';
  }

  Widget _categoryLabel() {
    final hits = widget.suggestionHitCount;
    // The marker belongs to the category that came from the rule; once it is
    // replaced in this dialog, the provenance is gone.
    final stillSuggested =
        hits != null && _categoryUuid == widget.row.categoryUuid;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(_categoryName(), overflow: TextOverflow.ellipsis)),
        if (stillSuggested) ...[
          const SizedBox(width: 6),
          const Icon(Icons.auto_awesome_outlined, size: 16),
          const SizedBox(width: 2),
          Text('$hits×'),
        ],
      ],
    );
  }

  Future<void> _pickCategory() async {
    final pick = await pickCategory(
      context,
      selected: _categoryUuid,
      allowNone: true,
    );
    if (pick == null) return;
    setState(() => _categoryUuid = pick.uuid);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _bookingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _bookingDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buchung bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Ausgabe')),
                ButtonSegment(value: false, label: Text('Einnahme')),
              ],
              selected: {_isExpense},
              onSelectionChanged: (selection) =>
                  setState(() => _isExpense = selection.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Betrag (EUR)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Verwendungszweck'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _counterparty,
              decoration: const InputDecoration(labelText: 'Gegenpartei'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickCategory,
              icon: const Icon(Icons.local_offer_outlined),
              label: _categoryLabel(),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(formatDateCompactDe(_bookingDate)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () {
            final cents = _parsedCents();
            final description = _description.text.trim();
            if (cents == null || description.isEmpty) return;
            Navigator.of(context).pop((
              row: widget.row.copyWith(
                bookingDate: _bookingDate,
                amountCents: cents,
                description: description,
                counterparty: _counterparty.text.trim(),
              ),
              categoryChanged: _categoryUuid != widget.row.categoryUuid,
              categoryUuid: _categoryUuid,
            ));
          },
          child: const Text('Übernehmen'),
        ),
      ],
    );
  }
}
