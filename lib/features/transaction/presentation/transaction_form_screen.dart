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
import '../../tagging/domain/tagging_suggest_service.dart';
import '../../tagging/presentation/suggestion_sheet.dart';
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
  final _counterpartyFocus = FocusNode();
  late bool _isExpense;
  late DateTime _bookingDate;
  late TransactionKind _kind;
  String? _accountUuid;
  String? _categoryUuid;
  List<CategorySuggestion> _suggestions = const [];

  /// The category the suggestion filled in, kept apart from [_categoryUuid] so
  /// a hand-picked category of the same value still counts as hand-picked.
  String? _suggestedCategoryUuid;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  bool get _isSuggested =>
      _suggestedCategoryUuid != null &&
      _categoryUuid == _suggestedCategoryUuid;

  int get _suggestedHitCount {
    for (final suggestion in _suggestions) {
      if (suggestion.categoryUuid == _categoryUuid) return suggestion.hitCount;
    }
    return 0;
  }

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
    _kind = existing?.kind ?? TransactionKind.regular;
    _accountUuid = existing?.accountUuid ?? widget.initialAccountUuid;
    _categoryUuid = existing?.categoryUuid;
    _counterpartyFocus.addListener(_onCounterpartyFocusChange);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _counterpartyController.dispose();
    _noteController.dispose();
    _counterpartyFocus.dispose();
    super.dispose();
  }

  void _onCounterpartyFocusChange() {
    if (!_counterpartyFocus.hasFocus) _suggestCategory();
  }

  /// Suggests on blur rather than per keystroke: every lookup hits Isar, and a
  /// half-typed counterparty matches nothing anyway.
  Future<void> _suggestCategory() async {
    final suggestions = await ref
        .read(taggingSuggestServiceProvider)
        .suggest(_counterpartyController.text.trim());
    if (!mounted) return;

    setState(() {
      _suggestions = suggestions;
      // A hand-picked category outranks a suggestion; only an empty field or an
      // untouched earlier suggestion may be overwritten.
      final replaceable = _categoryUuid == null || _isSuggested;
      if (suggestions.isEmpty) {
        if (_isSuggested) {
          _categoryUuid = null;
          _suggestedCategoryUuid = null;
        }
        return;
      }
      if (!replaceable) return;
      _categoryUuid = suggestions.first.categoryUuid;
      _suggestedCategoryUuid = suggestions.first.categoryUuid;
    });
  }

  /// Alternatives are overrides, not acceptances: picking the runner-up must
  /// let the learn hook raise its count, or it could never overtake the leader.
  Future<void> _chooseAlternative() async {
    final picked = await pickSuggestion(
      context,
      _suggestions,
      selectedCategoryUuid: _categoryUuid,
    );
    if (picked == null) return;
    setState(() {
      _categoryUuid = picked.categoryUuid;
      _suggestedCategoryUuid = null;
    });
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
    setState(() {
      _categoryUuid = pick.uuid;
      _suggestedCategoryUuid = null;
    });
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
      TransactionValidation.category(_categoryUuid, kind: _kind),
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
      // True only while the untouched suggestion is still in place; the learn
      // hook skips those rows so an accepted suggestion cannot reinforce itself.
      ..categoryAutoSuggested = _isSuggested
      ..kind = _kind;

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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Umbuchung'),
              subtitle: const Text(
                'Geld zwischen eigenen Konten — zählt in keiner Report-Summe '
                'und braucht keine Kategorie',
              ),
              value: _kind == TransactionKind.transfer,
              onChanged: (value) => setState(
                () => _kind =
                    value ? TransactionKind.transfer : TransactionKind.regular,
              ),
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
              subtitle: _isSuggested
                  ? _SuggestionHint(
                      hitCount: _suggestedHitCount,
                      onShowAlternatives:
                          _suggestions.length > 1 ? _chooseAlternative : null,
                    )
                  : _categoryUuid == null
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
              focusNode: _counterpartyFocus,
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

/// Marks the category row as machine-filled and offers the runners-up.
class _SuggestionHint extends StatelessWidget {
  const _SuggestionHint({
    required this.hitCount,
    required this.onShowAlternatives,
  });

  final int hitCount;
  final VoidCallback? onShowAlternatives;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(Icons.auto_awesome_outlined, size: 14, color: scheme.tertiary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            'Vorschlag · $hitCount×',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.tertiary),
          ),
        ),
        if (onShowAlternatives != null)
          TextButton(
            onPressed: onShowAlternatives,
            child: const Text('Alternativen'),
          ),
      ],
    );
  }
}
