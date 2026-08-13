import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/persistence/isar_provider.dart';
import '../../../core/sync/sync_provider.dart';
import 'tagging_learn_service.dart';
import 'tagging_rule_repository.dart';

final taggingRuleRepositoryProvider = Provider<TaggingRuleRepository>((ref) {
  return TaggingRuleRepository(
    ref.watch(isarProvider),
    ref.watch(syncAdapterProvider),
  );
});

final taggingLearnServiceProvider = Provider<TaggingLearnService>((ref) {
  return TaggingLearnService(ref.watch(taggingRuleRepositoryProvider));
});
