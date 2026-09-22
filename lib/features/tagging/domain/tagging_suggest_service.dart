import 'package:flutter/foundation.dart';

import '../../../core/text/normalize.dart';
import '../../category/domain/category_repository.dart';
import '../data/tagging_rule.dart';
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

/// The one suggestion a row may be filled with unattended, or null when the
/// rules do not agree well enough to act without being asked.
///
/// Unambiguous means: a single candidate category, or a strongest one whose
/// `hitCount` is **strictly** greater than the runner-up's. A tie is the case
/// where filling a row silently would teach the loser away (ticket 056).
CategorySuggestion? unambiguousSuggestion(List<CategorySuggestion> ordered) {
  if (ordered.isEmpty) return null;
  if (ordered.length == 1) return ordered.first;
  return ordered.first.hitCount > ordered[1].hitCount ? ordered.first : null;
}

abstract interface class TaggingSuggestService {
  /// Categories learned for [matchValue] within one kind of rule, strongest
  /// first. [matchField] is required on purpose — see
  /// `TaggingRuleRepository.findByMatch`.
  Future<List<CategorySuggestion>> suggest(
    String matchValue, {
    required TaggingMatchField matchField,
  });
}

class LocalTaggingSuggestService implements TaggingSuggestService {
  LocalTaggingSuggestService(this._rules, this._categories);

  final TaggingRuleRepository _rules;
  final CategoryRepository _categories;

  @override
  Future<List<CategorySuggestion>> suggest(
    String matchValue, {
    required TaggingMatchField matchField,
  }) async {
    final normalized = normalizeForMatching(matchValue);
    if (normalized.isEmpty) return const [];

    final rules = await _rules.findByMatch(normalized, matchField: matchField);
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
