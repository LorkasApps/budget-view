import 'package:flutter/foundation.dart';

import '../../../core/text/normalize.dart';
import '../../category/domain/category_repository.dart';
import 'tagging_rule_repository.dart';

/// One category a counterparty was assigned to before, with its confidence.
@immutable
class CategorySuggestion {
  const CategorySuggestion({
    required this.categoryUuid,
    required this.categoryName,
    required this.hitCount,
  });

  final String categoryUuid;

  /// Carried along so a suggestion can render without a second lookup.
  final String categoryName;

  /// How often the user made this assignment — the bare count is the whole
  /// confidence story, no derived percentage.
  final int hitCount;
}

abstract interface class TaggingSuggestService {
  /// Categories learned for [counterparty], strongest first.
  Future<List<CategorySuggestion>> suggest(String counterparty);
}

class LocalTaggingSuggestService implements TaggingSuggestService {
  LocalTaggingSuggestService(this._rules, this._categories);

  final TaggingRuleRepository _rules;
  final CategoryRepository _categories;

  @override
  Future<List<CategorySuggestion>> suggest(String counterparty) async {
    final normalized = normalizeForMatching(counterparty);
    if (normalized.isEmpty) return const [];

    final rules = await _rules.findByCounterparty(normalized);
    if (rules.isEmpty) return const [];

    // Archived and deleted categories are dropped: a rule may legally point at
    // either (see tagging.md), but the picker offers neither, so suggesting one
    // would be an offer the user cannot repeat by hand.
    final names = {
      for (final category in await _categories.findAll())
        category.uuid: category.name,
    };

    return [
      for (final rule in rules)
        if (names[rule.categoryUuid] case final String name)
          CategorySuggestion(
            categoryUuid: rule.categoryUuid,
            categoryName: name,
            hitCount: rule.hitCount,
          ),
    ];
  }
}
