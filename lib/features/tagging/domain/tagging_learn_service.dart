import '../../../core/text/normalize.dart';
import '../../transaction/data/transaction.dart';
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

    final matchValue = normalizeForMatching(transaction.counterparty);
    if (matchValue.isEmpty) return;

    await _rules.upsert(matchValue, categoryUuid);
  }
}
