import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/isar_provider.dart';
import '../../../core/sync/sync_provider.dart';
import '../../transaction/domain/transaction_providers.dart';
import '../data/line_item.dart';
import 'line_item_repository.dart';

final lineItemRepositoryProvider = Provider<LineItemRepository>((ref) {
  return LineItemRepository(
    ref.watch(isarProvider),
    ref.watch(syncAdapterProvider),
    ref.watch(transactionRepositoryProvider),
  );
});

/// Reactive positions of one booking, in manual order.
final lineItemsProvider = StreamProvider.family<List<LineItem>, String>(
  (ref, transactionUuid) async* {
    final repo = ref.watch(lineItemRepositoryProvider);
    final isar = ref.watch(isarProvider);

    yield await repo.findByTransaction(transactionUuid);
    await for (final _ in isar.lineItems.watchLazy()) {
      yield await repo.findByTransaction(transactionUuid);
    }
  },
);
