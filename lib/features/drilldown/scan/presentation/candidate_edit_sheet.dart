import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../../../category/data/category.dart';
import '../../../category/domain/category_providers.dart';
import '../../../category/presentation/category_chip.dart';
import '../../../category/presentation/category_picker.dart';
import '../../../transaction/data/transaction.dart';
import '../../domain/line_item_validation.dart';
import '../domain/receipt_line_item_parser.dart';

/// Edits one scan candidate. Returns the edited copy, or null when dismissed.
///
/// Mirrors `line_item_edit_sheet.dart` field for field — the same rules apply,
/// only nothing is persisted yet.
Future<LineItemCandidate?> showCandidateSheet(
  BuildContext context, {
  required LineItemCandidate candidate,
  required Transaction parent,
}) {
  return showModalBottomSheet<LineItemCandidate>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: _CandidateSheet(candidate: candidate, parent: parent),
    ),
  );
}

class _CandidateSheet extends ConsumerStatefulWidget {
  const _CandidateSheet({required this.candidate, required this.parent});

  final LineItemCandidate candidate;
  final Transaction parent;

  @override
  ConsumerState<_CandidateSheet> createState() => _CandidateSheetState();
}

class _CandidateSheetState extends ConsumerState<_CandidateSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitPriceController;
  String? _categoryUuid;

  @override
  void initState() {
    super.initState();
    final candidate = widget.candidate;
    _descriptionController =
        TextEditingController(text: candidate.description);
    _amountController = TextEditingController(
      text: candidate.amountCents == null
          ? ''
          : formatCentsPlain(candidate.amountCents!),
    );
    _quantityController = TextEditingController(
      text: candidate.quantity == null
          ? ''
          : LineItemValidation.quantityLabel(candidate.quantity!),
    );
    _unitPriceController = TextEditingController(
      text: candidate.unitPriceCents == null
          ? ''
          : formatCentsPlain(candidate.unitPriceCents!),
    );
    _categoryUuid = candidate.categoryUuid;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  double? get _parsedQuantity =>
      double.tryParse(_quantityController.text.trim().replaceAll(',', '.'));

  int? get _parsedUnitPrice => parseEurosToCents(_unitPriceController.text);

  String? get _mismatchWarning {
    final amountCents = parseEurosToCents(_amountController.text);
    if (amountCents == null) return null;
    return LineItemValidation.amountMismatch(
      quantity: _parsedQuantity,
      unitPriceCents: _parsedUnitPrice,
      amountCents: amountCents,
    );
  }

  String? _validateAmount(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return 'Betrag erforderlich';
    final cents = parseEurosToCents(text);
    if (cents == null) return 'Betrag nicht lesbar';
    return LineItemValidation.amount(cents);
  }

  String? _validateQuantity(String? raw) {
    if ((raw ?? '').trim().isEmpty) return null;
    if (_parsedQuantity == null) return 'Menge nicht lesbar';
    return LineItemValidation.quantity(_parsedQuantity);
  }

  String? _validateUnitPrice(String? raw) {
    if ((raw ?? '').trim().isEmpty) return null;
    if (_parsedUnitPrice == null) return 'Preis nicht lesbar';
    return LineItemValidation.unitPrice(_parsedUnitPrice);
  }

  String _inheritLabel(List<Category> categories) {
    final uuid = widget.parent.categoryUuid;
    if (uuid == null) return 'Erbt von der Buchung (ohne Kategorie)';
    for (final category in categories) {
      if (category.uuid == uuid) {
        return 'Erbt von der Buchung (${category.name})';
      }
    }
    return 'Erbt von der Buchung';
  }

  Future<void> _chooseCategory() async {
    final categories =
        ref.read(categoriesProvider(true)).valueOrNull ?? const <Category>[];
    final pick = await pickCategory(
      context,
      selected: _categoryUuid,
      allowNone: true,
      noneLabel: _inheritLabel(categories),
    );
    if (pick == null) return;
    setState(() => _categoryUuid = pick.uuid);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      widget.candidate.copyWith(
        description: _descriptionController.text.trim(),
        amountCents: parseEurosToCents(_amountController.text),
        quantity: _parsedQuantity,
        unitPriceCents: _parsedUnitPrice,
        parseState: LineItemParseState.ok,
        includeInSave: true,
        categoryUuid: _categoryUuid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warning = _mismatchWarning;
    final categories =
        ref.watch(categoriesProvider(true)).valueOrNull ?? const <Category>[];
    final raw = widget.candidate.rawOcrText;

    return Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          Text('Position aus Scan', style: theme.textTheme.titleMedium),
          if (raw.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              raw,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.outline,
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Beschreibung'),
            validator: LineItemValidation.description,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Betrag (€)',
              hintText: 'z. B. 1,19',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: _validateAmount,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Menge (optional)',
                    hintText: 'z. B. 1,5',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: _validateQuantity,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _unitPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Preis / Einheit (optional)',
                    hintText: 'z. B. 0,89',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: _validateUnitPrice,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          if (warning != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  size: 18,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(warning, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Kategorie'),
            subtitle:
                _categoryUuid == null ? Text(_inheritLabel(categories)) : null,
            trailing: _categoryUuid == null
                ? const Icon(Icons.chevron_right)
                : CategoryChip(categoryUuid: _categoryUuid),
            onTap: _chooseCategory,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
  }
}
