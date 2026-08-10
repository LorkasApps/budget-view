import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/money/money.dart';
import '../data/account.dart';
import '../data/account_type.dart';
import '../domain/account_providers.dart';
import '../domain/account_validation.dart';

/// Create (when [existing] is null) or edit an account.
class AccountFormScreen extends ConsumerStatefulWidget {
  const AccountFormScreen({super.key, this.existing});

  final Account? existing;

  @override
  ConsumerState<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends ConsumerState<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late AccountType _type;
  late DateTime _openingDate;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _balanceController = TextEditingController(
      text: existing == null
          ? ''
          : formatCentsPlain(existing.openingBalanceCents),
    );
    _type = existing?.type ?? AccountType.giro;
    _openingDate = existing?.openingDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _openingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _openingDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final dateError = AccountValidation.openingDate(_openingDate);
    if (dateError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(dateError)));
      return;
    }

    setState(() => _saving = true);
    final repo = ref.read(accountRepositoryProvider);
    final account = widget.existing ?? Account();
    account
      ..name = _nameController.text.trim()
      ..type = _type
      ..openingBalanceCents = parseEurosToCents(_balanceController.text)!
      ..openingDate = _openingDate;

    await repo.save(account);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Konto bearbeiten' : 'Neues Konto')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.words,
              validator: AccountValidation.name,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AccountType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Typ'),
              items: [
                for (final t in AccountType.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _balanceController,
              decoration: const InputDecoration(
                labelText: 'Startsaldo (€)',
                hintText: 'z. B. 1234,56 oder -50',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true, signed: true),
              validator: AccountValidation.openingBalance,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Startdatum'),
              subtitle: Text(formatDateDe(_openingDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
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
