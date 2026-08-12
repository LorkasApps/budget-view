import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/category.dart';
import '../domain/category_providers.dart';
import '../domain/category_repository.dart';
import '../domain/category_tree.dart';
import '../domain/category_validation.dart';
import 'category_style.dart';

/// Create or edit one category. A full screen rather than a bottom sheet, to
/// match the account and transaction forms and to give the icon and colour
/// grids room.
class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({
    super.key,
    this.existing,
    this.initialParentUuid,
  });

  final Category? existing;
  final String? initialParentUuid;

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  String? _parentUuid;
  late String _iconName;
  late String _colorHex;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _parentUuid = existing?.parentUuid ?? widget.initialParentUuid;
    _iconName = existing?.iconName ?? 'label';
    _colorHex = existing?.colorHex ?? categoryPalette.last;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save(List<Category> all) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final category = widget.existing ?? Category();
    category
      ..name = _name.text.trim()
      ..parentUuid = _parentUuid
      ..iconName = _iconName
      ..colorHex = _colorHex;

    try {
      await ref.read(categoryRepositoryProvider).save(category);
      if (mounted) Navigator.of(context).pop();
    } on CategoryInvalid catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider(false));
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Kategorie bearbeiten' : 'Neue Kategorie'),
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (all) {
          final blocked = widget.existing == null
              ? const <String>{}
              : ineligibleParents(all, widget.existing!);
          final options = all
              .where((category) => !blocked.contains(category.uuid))
              .toList();
          if (_parentUuid != null &&
              !options.any((option) => option.uuid == _parentUuid)) {
            _parentUuid = null;
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  textCapitalization: TextCapitalization.words,
                  validator: CategoryValidation.name,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: _parentUuid,
                  decoration: const InputDecoration(
                    labelText: 'Übergeordnete Kategorie',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Keine (Wurzel)'),
                    ),
                    for (final option in options)
                      DropdownMenuItem<String?>(
                        value: option.uuid,
                        child: Text(option.name),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _parentUuid = value),
                ),
                const SizedBox(height: 24),
                Text('Symbol', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _IconGrid(
                  selected: _iconName,
                  color: categoryColor(_colorHex),
                  onSelected: (name) => setState(() => _iconName = name),
                ),
                const SizedBox(height: 24),
                Text('Farbe', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _ColorGrid(
                  selected: _colorHex,
                  onSelected: (hex) => setState(() => _colorHex = hex),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _saving ? null : () => _save(all),
                  child: Text(isEdit ? 'Speichern' : 'Anlegen'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _IconGrid extends StatelessWidget {
  const _IconGrid({
    required this.selected,
    required this.color,
    required this.onSelected,
  });

  final String selected;
  final Color color;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in categoryIcons.entries)
          InkWell(
            onTap: () => onSelected(entry.key),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  width: entry.key == selected ? 2 : 1,
                  color: entry.key == selected
                      ? theme.colorScheme.primary
                      : theme.dividerColor,
                ),
              ),
              child: Icon(entry.value, color: color),
            ),
          ),
      ],
    );
  }
}

class _ColorGrid extends StatelessWidget {
  const _ColorGrid({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final hex in categoryPalette)
          InkWell(
            onTap: () => onSelected(hex),
            customBorder: const CircleBorder(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: categoryColor(hex),
                shape: BoxShape.circle,
                border: Border.all(
                  width: hex == selected ? 3 : 1,
                  color: hex == selected
                      ? theme.colorScheme.onSurface
                      : theme.dividerColor,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
