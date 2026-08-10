import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/money/money.dart';
import '../../account/data/account.dart';
import '../../account/domain/account_providers.dart';
import '../data/transaction.dart';
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
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _counterpartyController.dispose();
    _noteController.dispose();
    super.dispose();
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
      TransactionValidation.bookingDate(_bookingDate),
    ].whereType<String>();
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errors.first)));
      return;
    }

    setState(() => _saving = true);
    final magnitude = parseEurosToCents(_amountController.text)!;
    final transaction = widget.existing ?? Transaction();
    transaction
      ..accountUuid = _accountUuid!
      ..amountCents = _isExpense ? -magnitude : magnitude
      ..bookingDate = _bookingDate
      ..description = _descriptionController.text.trim()
      ..counterparty = _counterpartyController.text.trim()
      ..note = _noteController.text.trim();

    await ref.read(transactionRepositoryProvider).save(transaction);
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
            const SizedBox(height: 16),
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
          ],
        ),
      ),
    );
  }
}
