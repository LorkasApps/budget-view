import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/money/money.dart';
import '../../account/data/account.dart';
import '../../account/domain/account_providers.dart';
import '../../account/presentation/account_form_screen.dart';
import '../../category/data/category.dart';
import '../../category/domain/category_providers.dart';
import '../../category/presentation/category_chip.dart';
import '../../category/presentation/category_picker.dart';
import '../../tagging/domain/tagging_providers.dart';
import '../data/transaction.dart';
import '../domain/transaction_filter.dart';
import '../domain/transaction_providers.dart';
import '../import/presentation/pdf_import_screen.dart';
import 'category_filter_sheet.dart';
import 'transaction_form_screen.dart';

/// Transactions of one account, newest first.
class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key, required this.account});

  final Account account;

  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  // Not persisted: this is a pushed screen, not a tab, so its state ends with
  // it. A filter that still bit on the next visit is the kind of state one
  // forgets and then mistakes for missing data.
  final _queryController = TextEditingController();
  TransactionFilter _filter = const TransactionFilter();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _reset() {
    _queryController.clear();
    setState(() => _filter = const TransactionFilter());
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final transactionsAsync = ref.watch(transactionsProvider(account.uuid));

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          IconButton(
            tooltip: 'PDF importieren',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PdfImportScreen(accountUuid: account.uuid),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Konto bearbeiten',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AccountFormScreen(existing: account),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _AccountBalanceHeader(accountUuid: account.uuid),
          const Divider(height: 1),
          _FilterRow(
            controller: _queryController,
            category: _filter.category,
            onQueryChanged: (query) =>
                setState(() => _filter = TransactionFilter(
                      query: query,
                      category: _filter.category,
                    )),
            onCategoryChanged: (category) =>
                setState(() => _filter = TransactionFilter(
                      query: _filter.query,
                      category: category,
                    )),
          ),
          Expanded(
            child: transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (all) {
                if (all.isEmpty) {
                  return const Center(
                    child: Text('Noch keine Buchungen. Lege eine an.'),
                  );
                }

                final transactions = _filter.apply(all);
                if (transactions.isEmpty) {
                  return _NoMatch(onReset: _reset);
                }

                return ListView.separated(
                  itemCount: transactions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) =>
                      _TransactionTile(transaction: transactions[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                TransactionFormScreen(initialAccountUuid: account.uuid),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.controller,
    required this.category,
    required this.onQueryChanged,
    required this.onCategoryChanged,
  });

  final TextEditingController controller;
  final CategoryFilter category;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<CategoryFilter> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: 'Suchen',
                border: const OutlineInputBorder(),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Suche leeren',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          controller.clear();
                          onQueryChanged('');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CategoryFilterChip(category: category, onChanged: onCategoryChanged),
        ],
      ),
    );
  }
}

class _CategoryFilterChip extends ConsumerWidget {
  const _CategoryFilterChip({required this.category, required this.onChanged});

  final CategoryFilter category;
  final ValueChanged<CategoryFilter> onChanged;

  String _label(List<Category> categories) {
    switch (category.mode) {
      case CategoryFilterMode.all:
        return 'Alle Kategorien';
      case CategoryFilterMode.without:
        return 'Ohne Kategorie';
      case CategoryFilterMode.subtree:
        // `?` for a uuid pointing nowhere, as `CategoryChip` already does — an
        // archived category the filter still holds must not blank the label.
        final picked = categories.where((c) => c.uuid == category.rootUuid);
        return picked.isEmpty ? '?' : picked.first.name;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(categoriesProvider(false)).value ?? const <Category>[];

    return InputChip(
      avatar: const Icon(Icons.filter_list, size: 18),
      label: Text(_label(categories)),
      onPressed: () async {
        final picked = await pickCategoryFilter(context, selected: category);
        if (picked != null) onChanged(picked);
      },
      onDeleted:
          category.isAll ? null : () => onChanged(const CategoryFilter.all()),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Keine Buchung passt zu Suche und Filter.'),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onReset,
            child: const Text('Filter zurücksetzen'),
          ),
        ],
      ),
    );
  }
}

class _AccountBalanceHeader extends ConsumerWidget {
  const _AccountBalanceHeader({required this.accountUuid});

  final String accountUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(accountBalanceProvider(accountUuid));
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: balanceAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => const Text('Saldo nicht verfügbar'),
        data: (b) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Saldo', style: theme.textTheme.titleMedium),
                Text(
                  formatCentsEur(b.totalCents),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: b.totalCents < 0 ? theme.colorScheme.error : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Start ${formatCentsEur(b.openingBalanceCents)} · Buchungen ${formatCentsEur(b.transactionSumCents)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.transaction});

  final Transaction transaction;

  Future<void> _reassignCategory(BuildContext context, WidgetRef ref) async {
    final pick = await pickCategory(
      context,
      selected: transaction.categoryUuid,
      allowNone: true,
    );
    if (pick == null) return;

    transaction
      ..categoryUuid = pick.uuid
      ..categoryAutoSuggested = false;
    await ref.read(transactionRepositoryProvider).save(transaction);
    await ref.read(taggingLearnServiceProvider).learnFrom(transaction);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isExpense = transaction.amountCents < 0;
    final amountColor =
        isExpense ? theme.colorScheme.error : Colors.green.shade700;

    return Dismissible(
      key: ValueKey(transaction.uuid),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline),
      ),
      confirmDismiss: (_) async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Buchung löschen?'),
            content: Text('"${transaction.description}" wird gelöscht.'),
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
          await ref
              .read(transactionRepositoryProvider)
              .softDelete(transaction.uuid);
        }
        return false; // list refreshes reactively
      },
      child: ListTile(
        leading: Text(
          formatDateCompactDe(transaction.bookingDate),
          style: theme.textTheme.bodySmall,
        ),
        title: Text(transaction.description),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              CategoryChip(
                categoryUuid: transaction.categoryUuid,
                onTap: () => _reassignCategory(context, ref),
              ),
              // The merchant when one was read, because the row answers "who did
              // I pay" and `PayPal Europe S.a.r.l.` is the useless answer. The
              // form keeps showing the real counterparty: that is the booking's
              // identity and the dedupe key (ticket 047).
              if (transaction.taggingKey.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    transaction.taggingKey,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: Text(
          formatCentsEur(transaction.amountCents),
          style: theme.textTheme.titleMedium?.copyWith(color: amountColor),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TransactionFormScreen(existing: transaction),
          ),
        ),
      ),
    );
  }
}
