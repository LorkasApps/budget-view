import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/isar_provider.dart';
import '../../../core/sync/sync_provider.dart';
import '../data/category.dart';
import 'category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(
    ref.watch(isarProvider),
    ref.watch(syncAdapterProvider),
  );
});

/// Reactive flat category list. Param = include archived.
///
/// Emits an initial snapshot, then re-queries whenever the `Category`
/// collection changes. Callers shape it into a tree via `buildCategoryTree`.
final categoriesProvider =
    StreamProvider.family<List<Category>, bool>((ref, includeArchived) async* {
  final repository = ref.watch(categoryRepositoryProvider);
  final isar = ref.watch(isarProvider);

  yield await repository.findAll(includeArchived: includeArchived);
  await for (final _ in isar.categorys.watchLazy()) {
    yield await repository.findAll(includeArchived: includeArchived);
  }
});
