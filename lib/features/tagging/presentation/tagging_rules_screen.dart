import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../category/data/category.dart';
import '../../category/domain/category_providers.dart';
import '../../category/presentation/category_picker.dart';
import '../../category/presentation/category_style.dart';
import '../data/tagging_rule.dart';
import '../domain/tagging_providers.dart';
import '../domain/tagging_rule_repository.dart';

/// The rules learned from past assignments, and the two ways to curate them:
/// move a rule to another category, or drop it.
///
/// Creating a rule by hand is deliberately impossible — `matchValueNorm` is a
/// normalized string, and a hand-typed one that never matches would look exactly
/// like a working rule.
class TaggingRulesScreen extends ConsumerStatefulWidget {
  const TaggingRulesScreen({super.key});

  @override
  ConsumerState<TaggingRulesScreen> createState() => _TaggingRulesScreenState();
}

enum _RuleSort { strength, recent, counterparty }

extension on _RuleSort {
  String get label => switch (this) {
    _RuleSort.strength => 'Stärke',
    _RuleSort.recent => 'Zuletzt genutzt',
    _RuleSort.counterparty => 'Gegenseite',
  };
}

class _TaggingRulesScreenState extends ConsumerState<TaggingRulesScreen> {
  _RuleSort _sort = _RuleSort.strength;

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(taggingRulesProvider);
    // Archived categories included: a stale rule still names the category it
    // points at.
    final categoriesAsync = ref.watch(categoriesProvider(true));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tagging-Regeln'),
        actions: [
          PopupMenuButton<_RuleSort>(
            tooltip: 'Sortierung',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (sort) => setState(() => _sort = sort),
            itemBuilder: (_) => [
              for (final sort in _RuleSort.values)
                PopupMenuItem(value: sort, child: Text(sort.label)),
            ],
          ),
        ],
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (rules) {
          if (rules.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Noch keine Regeln gelernt. Sie entstehen, sobald du '
                  'Buchungen Kategorien zuweist.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final categories = categoriesAsync.valueOrNull ?? const <Category>[];
          final byUuid = {for (final c in categories) c.uuid: c};
          final stale = rules.where((r) => _isStale(r, byUuid)).toList();
          final visible = _sorted(rules);

          return Column(
            children: [
              if (stale.isNotEmpty)
                _StaleBanner(
                  count: stale.length,
                  onDelete: () => _deleteStale(stale),
                ),
              Expanded(
                child: ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => _RuleTile(
                    rule: visible[i],
                    category: byUuid[visible[i].categoryUuid],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<TaggingRule> _sorted(List<TaggingRule> rules) {
    // The provider already hands over strongest-first; the other two orders are
    // comparators here rather than queries, like the repository does it.
    if (_sort == _RuleSort.strength) return rules;
    final sorted = [...rules];
    switch (_sort) {
      case _RuleSort.recent:
        sorted.sort((a, b) => b.lastAssignedAt.compareTo(a.lastAssignedAt));
      case _RuleSort.counterparty:
        sorted.sort(
          (a, b) => a.matchValueNorm.toLowerCase().compareTo(
            b.matchValueNorm.toLowerCase(),
          ),
        );
      case _RuleSort.strength:
        break;
    }
    return sorted;
  }

  Future<void> _deleteStale(List<TaggingRule> stale) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${stale.length} veraltete Regeln löschen?'),
        content: const Text(
          'Betroffen sind nur Regeln, deren Kategorie archiviert ist oder '
          'fehlt. Andere Regeln bleiben unberührt.',
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
    if (!(ok ?? false)) return;

    final repository = ref.read(taggingRuleRepositoryProvider);
    for (final rule in stale) {
      await repository.delete(rule.uuid);
    }
  }
}

/// A rule points at a category by uuid that nobody validates, so both an
/// archived and an unresolvable target are legal states — and equally useless.
bool _isStale(TaggingRule rule, Map<String, Category> byUuid) {
  final category = byUuid[rule.categoryUuid];
  return category == null || category.archived;
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.count, required this.onDelete});

  final int count;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                count == 1
                    ? '1 Regel zeigt auf eine archivierte oder fehlende Kategorie'
                    : '$count Regeln zeigen auf archivierte oder fehlende Kategorien',
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onDelete, child: const Text('Löschen')),
          ],
        ),
      ),
    );
  }
}

class _RuleTile extends ConsumerWidget {
  const _RuleTile({required this.rule, required this.category});

  final TaggingRule rule;
  final Category? category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(taggingRuleRepositoryProvider);
    final stale = category == null || category!.archived;
    final categoryName = category?.name ?? 'Kategorie fehlt';
    final subtitle = [
      categoryName,
      '${rule.hitCount}×',
      formatDateDe(rule.lastAssignedAt),
      if (stale) 'veraltet',
    ].join(' · ');

    return Dismissible(
      key: ValueKey(rule.uuid),
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
            title: const Text('Regel löschen?'),
            content: Text(
              '"${rule.matchValueNorm}" wird künftig nicht mehr '
              'vorgeschlagen. Bestehende Buchungen bleiben unverändert.',
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
          await repository.delete(rule.uuid);
        }
        return false; // the list updates reactively; don't drop the tile itself
      },
      child: ListTile(
        leading: Icon(
          categoryIcon(category?.iconName ?? 'label'),
          color: categoryColor(category?.colorHex ?? ''),
        ),
        title: Text(rule.matchValueNorm),
        subtitle: Text(subtitle),
        trailing: stale
            ? Icon(
                Icons.warning_amber_outlined,
                color: Theme.of(context).colorScheme.error,
              )
            : null,
        onTap: () => _remap(context, repository),
      ),
    );
  }

  Future<void> _remap(
    BuildContext context,
    TaggingRuleRepository repository,
  ) async {
    final pick = await pickCategory(context, selected: rule.categoryUuid);
    final uuid = pick?.uuid;
    if (uuid == null || uuid == rule.categoryUuid) return;
    await repository.remap(rule.uuid, uuid);
  }
}
