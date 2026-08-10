import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../data/account.dart';
import '../data/account_type.dart';
import '../../transaction/presentation/transaction_list_screen.dart';
import '../domain/account_providers.dart';
import 'account_form_screen.dart';

class AccountListScreen extends ConsumerStatefulWidget {
  const AccountListScreen({super.key});

  @override
  ConsumerState<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends ConsumerState<AccountListScreen> {
  bool _showArchived = false;

  Future<void> _openForm({Account? existing}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountFormScreen(existing: existing),
      ),
    );
  }

  Future<void> _openTransactions(Account account) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionListScreen(account: account),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider(_showArchived));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Konten'),
        actions: [
          IconButton(
            tooltip: _showArchived ? 'Archivierte ausblenden' : 'Archivierte anzeigen',
            icon: Icon(_showArchived ? Icons.visibility_off : Icons.archive_outlined),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return const Center(child: Text('Noch keine Konten. Lege eins an.'));
          }
          return Column(
            children: [
              _TotalHeader(includeArchived: _showArchived),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: accounts.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) => _AccountTile(
                    account: accounts[i],
                    onOpen: () => _openTransactions(accounts[i]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account, required this.onOpen});

  final Account account;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(accountRepositoryProvider);
    final subtitle = account.archived
        ? '${account.type.label} · archiviert'
        : account.type.label;

    return Dismissible(
      key: ValueKey(account.uuid),
      direction: account.archived
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.archive),
      ),
      confirmDismiss: (_) async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Konto archivieren?'),
            content: Text('"${account.name}" wird archiviert. Transaktionen bleiben erhalten.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Archivieren'),
              ),
            ],
          ),
        );
        if (ok ?? false) {
          await repo.softDelete(account.uuid);
        }
        return false; // list updates reactively; don't remove the tile itself
      },
      child: ListTile(
        title: Text(account.name),
        subtitle: Text(subtitle),
        trailing: _BalanceLabel(accountUuid: account.uuid),
        onTap: onOpen,
        onLongPress: account.archived
            ? () => repo.restore(account.uuid)
            : null,
      ),
    );
  }
}

class _BalanceLabel extends ConsumerWidget {
  const _BalanceLabel({required this.accountUuid});

  final String accountUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(accountBalanceProvider(accountUuid));
    final theme = Theme.of(context);
    return balanceAsync.when(
      loading: () => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, _) => const Icon(Icons.error_outline, size: 18),
      data: (b) => Text(
        formatCentsEur(b.totalCents),
        style: theme.textTheme.titleMedium?.copyWith(
          color: b.totalCents < 0 ? theme.colorScheme.error : null,
        ),
      ),
    );
  }
}

class _TotalHeader extends ConsumerWidget {
  const _TotalHeader({required this.includeArchived});

  final bool includeArchived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAsync = ref.watch(totalBalanceProvider(includeArchived));
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Gesamt', style: theme.textTheme.titleMedium),
          totalAsync.when(
            loading: () => const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, _) => const Icon(Icons.error_outline, size: 18),
            data: (cents) => Text(
              formatCentsEur(cents),
              style: theme.textTheme.titleLarge?.copyWith(
                color: cents < 0 ? theme.colorScheme.error : null,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
