import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/isar_provider.dart';
import '../../../core/sync/sync_provider.dart';
import '../data/account.dart';
import '../data/local_balance_service.dart';
import 'account_balance.dart';
import 'account_repository.dart';
import 'balance_service.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(
    ref.watch(isarProvider),
    ref.watch(syncAdapterProvider),
  );
});

final balanceServiceProvider = Provider<BalanceService>((ref) {
  return LocalBalanceService(ref.watch(isarProvider));
});

/// Reactive balance for a single account.
final accountBalanceProvider =
    StreamProvider.family<AccountBalance, String>((ref, accountUuid) {
  return ref.watch(balanceServiceProvider).watch(accountUuid);
});

/// Reactive total across accounts. Param = include archived.
final totalBalanceProvider =
    StreamProvider.family<int, bool>((ref, includeArchived) {
  return ref
      .watch(balanceServiceProvider)
      .watchTotalCents(includeArchived: includeArchived);
});

/// Reactive account list. Param = include archived accounts.
///
/// Emits an initial snapshot, then re-queries via the repository whenever the
/// Isar `Account` collection changes.
final accountsProvider =
    StreamProvider.family<List<Account>, bool>((ref, includeArchived) async* {
  final repo = ref.watch(accountRepositoryProvider);
  final isar = ref.watch(isarProvider);

  yield await repo.findAll(includeArchived: includeArchived);
  await for (final _ in isar.accounts.watchLazy()) {
    yield await repo.findAll(includeArchived: includeArchived);
  }
});
