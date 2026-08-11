import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/money/money.dart';
import '../../account/data/account.dart';
import '../../account/domain/account_providers.dart';
import '../../account/presentation/account_form_screen.dart';
import '../data/transaction.dart';
import '../domain/transaction_providers.dart';
import '../import/presentation/pdf_import_screen.dart';
import 'transaction_form_screen.dart';

/// Transactions of one account, newest first.
class TransactionListScreen extends ConsumerWidget {
  const TransactionListScreen({super.key, required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          Expanded(
            child: transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const Center(
                    child: Text('Noch keine Buchungen. Lege eine an.'),
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
        subtitle: transaction.counterparty.isEmpty
            ? null
            : Text(
                transaction.counterparty,
                style: theme.textTheme.bodySmall,
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
