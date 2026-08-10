import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/isar_provider.dart';
import '../../../core/sync/sync_provider.dart';
import '../data/account.dart';
import 'account_repository.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(
    ref.watch(isarProvider),
    ref.watch(syncAdapterProvider),
  );
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
