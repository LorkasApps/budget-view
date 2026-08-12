import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/money/money.dart';
import '../../account/data/account.dart';
import '../../account/domain/account_providers.dart';
import '../../account/presentation/account_form_screen.dart';
import '../../category/presentation/category_chip.dart';
import '../../category/presentation/category_picker.dart';
import '../data/transaction.dart';
import '../domain/transaction_providers.dart';
import '../import/presentation/pdf_import_screen.dart';
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
  bool _onlyUncategorized = false;

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final transactionsAsync = ref.watch(transactionsProvider(account.uuid));

    return Scaffold(
      appBar: AppBar(
        title: Text(account.name),
        actions: [
          IconButton(
            tooltip: _onlyUncategorized
                ? 'Alle Buchungen zeigen'
                : 'Nur ohne Kategorie',
            icon: Icon(
              _onlyUncategorized ? Icons.label : Icons.label_off_outlined,
            ),
            onPressed: () =>
                setState(() => _onlyUncategorized = !_onlyUncategorized),
          ),
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

                final transactions = _onlyUncategorized
                    ? all.where((t) => t.categoryUuid == null).toList()
                    : all;
                if (transactions.isEmpty) {
                  return const Center(
                    child: Text('Alle Buchungen haben eine Kategorie.'),
                  );
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

    transaction.categoryUuid = pick.uuid;
    await ref.read(transactionRepositoryProvider).save(transaction);
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
              if (transaction.counterparty.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    transaction.counterparty,
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
