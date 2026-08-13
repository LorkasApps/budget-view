import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../category/data/category.dart';
import '../../category/domain/category_providers.dart';
import '../../category/presentation/category_chip.dart';
import '../../category/presentation/category_picker.dart';
import '../../transaction/data/transaction.dart';
import '../data/line_item.dart';
import '../domain/line_item_providers.dart';
import '../domain/line_item_repository.dart';
import '../domain/line_item_validation.dart';

/// Create (when [existing] is null) or edit one position of [parent].
///
/// The amount field holds the magnitude; the sign comes from [parent], so there
/// is no expense/income toggle here.
Future<void> showLineItemSheet(
  BuildContext context, {
  required Transaction parent,
  LineItem? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: _LineItemSheet(parent: parent, existing: existing),
    ),
  );
}

class _LineItemSheet extends ConsumerStatefulWidget {
  const _LineItemSheet({required this.parent, this.existing});

  final Transaction parent;
  final LineItem? existing;

  @override
  ConsumerState<_LineItemSheet> createState() => _LineItemSheetState();
}

class _LineItemSheetState extends ConsumerState<_LineItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitPriceController;
  String? _categoryUuid;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _descriptionController =
        TextEditingController(text: existing?.description ?? '');
    _amountController = TextEditingController(
      text: existing == null ? '' : formatCentsPlain(existing.amountCents.abs()),
    );
    _quantityController = TextEditingController(
      text: existing?.quantity == null
          ? ''
          : LineItemValidation.quantityLabel(existing!.quantity!),
    );
    _unitPriceController = TextEditingController(
      text: existing?.unitPriceCents == null
          ? ''
          : formatCentsPlain(existing!.unitPriceCents!),
    );
    _categoryUuid = existing?.categoryUuid;
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

  /// Name of the booking's own category, or null while it is uncategorized.
  String? _parentCategoryName(List<Category> categories) {
    final uuid = widget.parent.categoryUuid;
    if (uuid == null) return null;
    for (final category in categories) {
      if (category.uuid == uuid) return category.name;
    }
    return null;
  }

  /// Takes the category list from the caller so `build` can pass a watched
  /// snapshot while the tap handler passes a freshly read one — watching
  /// outside build is not allowed, and reading during build would freeze the
  /// label at the stream's loading state.
  String _inheritLabel(List<Category> categories) {
    final name = _parentCategoryName(categories);
    return name == null
        ? 'Erbt von der Buchung (ohne Kategorie)'
        : 'Erbt von der Buchung ($name)';
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final magnitude = parseEurosToCents(_amountController.text)!;
    final item =
        widget.existing ?? (LineItem()..transactionUuid = widget.parent.uuid);
    item
      ..amountCents = widget.parent.amountCents < 0 ? -magnitude : magnitude
      ..description = _descriptionController.text.trim()
      ..quantity = _parsedQuantity
      ..unitPriceCents = _parsedUnitPrice
      ..categoryUuid = _categoryUuid;

    setState(() => _saving = true);
    try {
      await ref.read(lineItemRepositoryProvider).save(item);
    } on LineItemInvalid catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final warning = _mismatchWarning;
    final categories =
        ref.watch(categoriesProvider(true)).valueOrNull ?? const <Category>[];

    return Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _isEdit ? 'Position bearbeiten' : 'Neue Position',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    warning,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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
            onTap: _saving ? null : _chooseCategory,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_isEdit ? 'Speichern' : 'Hinzufügen'),
          ),
        ],
      ),
    );
  }
}
