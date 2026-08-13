import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/money/money.dart';
import '../../account/data/account.dart';
import '../../account/domain/account_providers.dart';
import '../../category/presentation/category_chip.dart';
import '../../category/presentation/category_picker.dart';
import '../../drilldown/domain/line_item_providers.dart';
import '../../drilldown/presentation/line_items_section.dart';
import '../../import/domain/import_providers.dart';
import '../../tagging/domain/tagging_providers.dart';
import '../data/transaction.dart';
import '../domain/dedupe_hash.dart';
import '../domain/transaction_providers.dart';
import '../domain/transaction_validation.dart';

/// Create (when [existing] is null) or edit a transaction.
///
/// The amount field holds the magnitude; the expense/income toggle supplies
/// the sign (negative = expense).
class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({
    super.key,
    this.existing,
    this.initialAccountUuid,
  });

  final Transaction? existing;
  final String? initialAccountUuid;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _counterpartyController;
  late final TextEditingController _noteController;
  late bool _isExpense;
  late DateTime _bookingDate;
  String? _accountUuid;
  String? _categoryUuid;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _isExpense = existing == null ? true : existing.amountCents < 0;
    _amountController = TextEditingController(
      text: existing == null
          ? ''
          : formatCentsPlain(existing.amountCents.abs()),
    );
    _descriptionController =
        TextEditingController(text: existing?.description ?? '');
    _counterpartyController =
        TextEditingController(text: existing?.counterparty ?? '');
    _noteController = TextEditingController(text: existing?.note ?? '');
    _bookingDate = existing?.bookingDate ?? DateTime.now();
    _accountUuid = existing?.accountUuid ?? widget.initialAccountUuid;
    _categoryUuid = existing?.categoryUuid;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _counterpartyController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Shows existing bookings that would hash the same and asks whether to save
  /// anyway. Returns false only if the user backs out.
  ///
  /// A booking being edited always matches itself, so it is filtered out — the
  /// warning is about *other* bookings.
  Future<bool> _confirmDespiteDuplicates(int amountCents) async {
    final hash = dedupeHashOf(
      amountCents: amountCents,
      bookingDate: _bookingDate,
      counterparty: _counterpartyController.text.trim(),
    );

    final matches = (await ref
            .read(duplicateCheckerProvider)
            .findTransactionMatches(hash, accountUuid: _accountUuid!))
        .where((match) => match.uuid != widget.existing?.uuid)
        .toList();
    if (matches.isEmpty || !mounted) return true;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Möglicher Doppel-Eintrag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              matches.length == 1
                  ? 'Es gibt bereits eine Buchung mit gleichem Betrag, Datum '
                      'und Empfänger:'
                  : 'Es gibt bereits ${matches.length} Buchungen mit gleichem '
                      'Betrag, Datum und Empfänger:',
            ),
            const SizedBox(height: 8),
            for (final match in matches)
              Text(
                '${formatDateDe(match.bookingDate)} · '
                '${formatCentsEur(match.amountCents)} · ${match.description}',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Trotzdem speichern'),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  Future<void> _chooseCategory() async {
    final pick = await pickCategory(context, selected: _categoryUuid);
    if (pick == null) return;
    setState(() => _categoryUuid = pick.uuid);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _bookingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _bookingDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final errors = [
      TransactionValidation.account(_accountUuid),
      TransactionValidation.category(_categoryUuid),
      TransactionValidation.bookingDate(_bookingDate),
    ].whereType<String>();
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errors.first)));
      return;
    }

    final magnitude = parseEurosToCents(_amountController.text)!;
    final amountCents = _isExpense ? -magnitude : magnitude;
    if (!await _confirmDespiteDuplicates(amountCents)) return;

    setState(() => _saving = true);
    final transaction = widget.existing ?? Transaction();
    transaction
      ..accountUuid = _accountUuid!
      ..categoryUuid = _categoryUuid
      ..amountCents = amountCents
      ..bookingDate = _bookingDate
      ..description = _descriptionController.text.trim()
      ..counterparty = _counterpartyController.text.trim()
      ..note = _noteController.text.trim()
      // The user picked this category by hand, so it is no longer a suggestion.
      ..categoryAutoSuggested = false;

    await ref.read(transactionRepositoryProvider).save(transaction);
    await ref.read(taggingLearnServiceProvider).learnFrom(transaction);
    // A changed booking amount moves the gap its positions have to close. No-op
    // for a booking without positions, which is the case for every fresh one.
    await ref.read(restpostenReconcilerProvider).reconcile(transaction.uuid);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider(false));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Buchung bearbeiten' : 'Neue Buchung'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Ausgabe'),
                  icon: Icon(Icons.remove),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Einnahme'),
                  icon: Icon(Icons.add),
                ),
              ],
              selected: {_isExpense},
              onSelectionChanged: (s) => setState(() => _isExpense = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Betrag (€)',
                hintText: 'z. B. 47,32',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: TransactionValidation.amount,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Beschreibung'),
              validator: TransactionValidation.description,
            ),
            const SizedBox(height: 16),
            accountsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Konten konnten nicht geladen werden: $e'),
              data: (accounts) => DropdownButtonFormField<String>(
                initialValue: _accountUuid,
                decoration: const InputDecoration(labelText: 'Konto'),
                items: [
                  for (final Account a in accounts)
                    DropdownMenuItem(value: a.uuid, child: Text(a.name)),
                ],
                onChanged: (v) => setState(() => _accountUuid = v),
                validator: (v) => TransactionValidation.account(v),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Kategorie'),
              subtitle: _categoryUuid == null
                  ? Text(
                      'Pflichtfeld',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    )
                  : null,
              trailing: CategoryChip(categoryUuid: _categoryUuid),
              onTap: _saving ? null : _chooseCategory,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Buchungsdatum'),
              subtitle: Text(formatDateDe(_bookingDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _counterpartyController,
              decoration: const InputDecoration(
                labelText: 'Zahlungsempfänger / Absender (optional)',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Notiz (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_isEdit ? 'Speichern' : 'Anlegen'),
            ),
            // Positions hang off a persisted booking, so they only appear once
            // the transaction has a uuid.
            if (_isEdit) ...[
              const SizedBox(height: 24),
              const Divider(),
              LineItemsSection(transaction: widget.existing!),
            ],
          ],
        ),
      ),
    );
  }
}
