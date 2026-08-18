import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../account/domain/account_providers.dart';

/// Result of [pickAccount]. Wrapping the uuid keeps "all accounts" (`null`)
/// distinguishable from a dismissed sheet, like `CategoryPick` does.
class AccountPick {
  const AccountPick(this.accountUuid);

  final String? accountUuid;
}

Future<AccountPick?> pickAccount(
  BuildContext context, {
  String? selected,
}) => showModalBottomSheet<AccountPick>(
  context: context,
  showDragHandle: true,
  builder: (_) => _AccountFilterSheet(selected: selected),
);

class _AccountFilterSheet extends ConsumerWidget {
  const _AccountFilterSheet({required this.selected});

  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider(false)).valueOrNull ?? const [];
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.all_inbox_outlined),
            title: const Text('Alle Konten'),
            trailing: selected == null ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(context).pop(const AccountPick(null)),
          ),
          const Divider(height: 1),
          for (final account in accounts)
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(account.name),
              trailing: selected == account.uuid ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(context).pop(AccountPick(account.uuid)),
            ),
        ],
      ),
    );
  }
}
