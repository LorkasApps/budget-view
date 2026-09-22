import '../../../core/text/normalize.dart';
import '../../transaction/data/transaction.dart';
import '../data/tagging_rule.dart';
import 'tagging_rule_repository.dart';

/// Turns the user's own category assignments into tagging rules.
///
/// Called from the UI paths that assign a category, not from a hook inside
/// `TransactionRepository.save`: a hook there would invert the documented
/// `Tagging → Transaction` direction (see decisions.md).
class TaggingLearnService {
  TaggingLearnService(this._rules);

  final TaggingRuleRepository _rules;

  /// No-op unless the booking carries a user-chosen category and a counterparty
  /// worth matching on. An accepted auto-suggestion teaches nothing — it would
  /// only reinforce whatever the rule already claimed. A transfer teaches
  /// nothing either: a rule learned from it would later propose a spending
  /// category for money that never left (ticket 032).
  Future<void> learnFrom(Transaction transaction) async {
    if (transaction.kind == TransactionKind.transfer) return;

    final categoryUuid = transaction.categoryUuid;
    if (categoryUuid == null) return;
    if (transaction.categoryAutoSuggested) return;

    // The merchant when the purpose text named one, the counterparty otherwise:
    // one PayPal rule for every shop would suggest a lottery (ticket 047).
    await _learn(
      transaction.taggingKey,
      categoryUuid,
      TaggingMatchField.counterparty,
    );
  }

  /// The same for one scanned or hand-entered position, keyed on the article
  /// description instead of the counterparty (ticket 056).
  ///
  /// Takes the description as a plain string rather than a `LineItem`: Tagging
  /// holds a category only by uuid and imports no other feature's entity, and
  /// the new `Drilldown → Tagging` edge should not drag one in either.
  ///
  /// [wasSuggested] carries the same meaning as `categoryAutoSuggested` on a
  /// booking — a category this service proposed itself teaches nothing. Unlike
  /// `learnFrom` there is no transfer case: a position is never one.
  Future<void> learnFromPosition({
    required String description,
    required String? categoryUuid,
    required bool wasSuggested,
  }) async {
    if (categoryUuid == null) return;
    if (wasSuggested) return;

    await _learn(description, categoryUuid, TaggingMatchField.description);
  }

  Future<void> _learn(
    String rawKey,
    String categoryUuid,
    TaggingMatchField matchField,
  ) async {
    final matchValue = normalizeForMatching(rawKey);
    if (matchValue.isEmpty) return;

    await _rules.upsert(matchValue, categoryUuid, matchField: matchField);
  }
}
