import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/isar_provider.dart';
import '../../../core/sync/sync_provider.dart';
import '../../account/domain/account_providers.dart';
import '../data/transaction.dart';
import 'transaction_repository.dart';
import 'transfer_pair_service.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(
    ref.watch(isarProvider),
    ref.watch(syncAdapterProvider),
  );
});

final transferPairServiceProvider = Provider<TransferPairService>((ref) {
  return TransferPairService(
    ref.watch(transactionRepositoryProvider),
    ref.watch(accountRepositoryProvider),
  );
});

/// Reactive transaction list for one account (newest first).
final transactionsProvider =
    StreamProvider.family<List<Transaction>, String>((ref, accountUuid) async* {
  final repo = ref.watch(transactionRepositoryProvider);
  final isar = ref.watch(isarProvider);

  yield await repo.findByAccount(accountUuid);
  await for (final _ in isar.transactions.watchLazy()) {
    yield await repo.findByAccount(accountUuid);
  }
});
