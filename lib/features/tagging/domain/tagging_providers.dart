import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/isar_provider.dart';
import '../../../core/sync/sync_provider.dart';
import '../../category/domain/category_providers.dart';
import 'tagging_learn_service.dart';
import 'tagging_rule_repository.dart';
import 'tagging_suggest_service.dart';

final taggingRuleRepositoryProvider = Provider<TaggingRuleRepository>((ref) {
  return TaggingRuleRepository(
    ref.watch(isarProvider),
    ref.watch(syncAdapterProvider),
  );
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
