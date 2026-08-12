import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/isar_provider.dart';
import '../../../core/sync/sync_provider.dart';
import '../../transaction/domain/transaction_providers.dart';
import 'duplicate_checker.dart';
import 'imported_source_repository.dart';

final importedSourceRepositoryProvider = Provider<ImportedSourceRepository>((
  ref,
) {
  return ImportedSourceRepository(
    ref.watch(isarProvider),
    ref.watch(syncAdapterProvider),
  );
});

final duplicateCheckerProvider = Provider<DuplicateChecker>((ref) {
  return LocalDuplicateChecker(
    ref.watch(transactionRepositoryProvider),
    ref.watch(importedSourceRepositoryProvider),
  );
});
