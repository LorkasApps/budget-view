import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/isar_provider.dart';
import '../../../core/sync/sync_provider.dart';
import '../../category/domain/category_providers.dart';
import '../data/tagging_rule.dart';
import 'tagging_learn_service.dart';
import 'tagging_rule_repository.dart';
import 'tagging_suggest_service.dart';

final taggingRuleRepositoryProvider = Provider<TaggingRuleRepository>((ref) {
  return TaggingRuleRepository(
    ref.watch(isarProvider),
    ref.watch(syncAdapterProvider),
  );
});

/// Reactive rule list, strongest first — the repository's own ordering.
///
/// Emits an initial snapshot, then re-queries whenever the Isar `TaggingRule`
/// collection changes, so a remap or delete lands without a manual refresh.
final taggingRulesProvider = StreamProvider<List<TaggingRule>>((ref) async* {
  final repository = ref.watch(taggingRuleRepositoryProvider);
  final isar = ref.watch(isarProvider);

  yield await repository.findAll();
  await for (final _ in isar.taggingRules.watchLazy()) {
    yield await repository.findAll();
  }
});

final taggingLearnServiceProvider = Provider<TaggingLearnService>((ref) {
  return TaggingLearnService(ref.watch(taggingRuleRepositoryProvider));
});

/// Interface-typed so a widget test can hand in a fake instead of an Isar.
final taggingSuggestServiceProvider = Provider<TaggingSuggestService>((ref) {
  return LocalTaggingSuggestService(
    ref.watch(taggingRuleRepositoryProvider),
    ref.watch(categoryRepositoryProvider),
  );
});
