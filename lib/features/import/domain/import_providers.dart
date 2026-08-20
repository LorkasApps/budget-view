import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/isar_provider.dart';
import '../../../core/sync/sync_provider.dart';
import '../../transaction/domain/transaction_providers.dart';
import '../data/imported_source.dart';
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

/// Reactive import history, newest first.
///
/// Emits an initial snapshot, then re-queries via the repository whenever the
/// Isar `ImportedSource` collection changes.
final importedSourcesProvider = StreamProvider<List<ImportedSource>>((
  ref,
) async* {
  final repo = ref.watch(importedSourceRepositoryProvider);
  final isar = ref.watch(isarProvider);

  yield await repo.findAll();
  await for (final _ in isar.importedSources.watchLazy()) {
    yield await repo.findAll();
  }
});

final duplicateCheckerProvider = Provider<DuplicateChecker>((ref) {
  return LocalDuplicateChecker(
    ref.watch(transactionRepositoryProvider),
    ref.watch(importedSourceRepositoryProvider),
  );
});
