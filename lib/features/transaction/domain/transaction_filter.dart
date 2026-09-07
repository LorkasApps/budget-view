import 'package:flutter/foundation.dart' show immutable;

import '../../../core/money/money.dart';
import '../data/transaction.dart';

/// Which categories a booking list shows.
enum CategoryFilterMode { all, without, subtree }

/// The category half of [TransactionFilter].
///
/// [CategoryFilter.subtree] carries the picked category *plus its descendants*,
/// resolved by the caller through `subtreeUuids`: the report has drilled into a
/// category including its children since ticket 020, so picking `Lebensmittel`
/// and not seeing `Getränke` would read as a bug.
@immutable
class CategoryFilter {
  const CategoryFilter.all()
      : mode = CategoryFilterMode.all,
        rootUuid = '',
        uuids = const {};

  const CategoryFilter.without()
      : mode = CategoryFilterMode.without,
        rootUuid = '',
        uuids = const {};

  const CategoryFilter.subtree({required this.rootUuid, required this.uuids})
      : mode = CategoryFilterMode.subtree;

  final CategoryFilterMode mode;

  /// The category the user picked. Kept beside [uuids] so the control can label
  /// and tick itself without re-deriving which of the uuids was the root.
  final String rootUuid;

  final Set<String> uuids;

  bool get isAll => mode == CategoryFilterMode.all;
}

/// Narrows an account's bookings by word search and category, combined by AND.
///
/// A pure predicate over an already-streamed list rather than an Isar query:
/// substring over five fields, a category subtree and the transfer rule are
/// plain Dart this way, so unit tests and `testWidgets` can both drive them —
/// real Isar never completes inside the fake-async zone (`decisions.md`,
/// 2026-08-12). Cost accepted: the work grows with the account's history.
@immutable
class TransactionFilter {
  const TransactionFilter({
    this.query = '',
    this.category = const CategoryFilter.all(),
  });

  final String query;
  final CategoryFilter category;

  bool get isActive => query.trim().isNotEmpty || !category.isAll;

  List<Transaction> apply(List<Transaction> transactions) =>
      isActive ? transactions.where(matches).toList() : transactions;

  bool matches(Transaction transaction) =>
      _matchesQuery(transaction) && _matchesCategory(transaction);

  /// Case-insensitive substring, otherwise literal — `Bruehe` does not find
  /// `Brühe`, exactly as the category picker's search behaves (ticket 038).
  /// `normalizeForMatching` stays out of it: it exists for machine comparison
  /// in dedupe and tagging, and widening it would silently change search.
  bool _matchesQuery(Transaction transaction) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;

    for (final field in [
      transaction.description,
      transaction.counterparty,
      // The row shows the merchant instead of the counterparty since 047, so
      // leaving it out means searching for what you see and finding nothing.
      transaction.merchant,
      transaction.note,
      // Both spellings of the amount: the row shows `1.234,56 €` while a user
      // types `1234,56`, and the grouping dot would swallow the match.
      formatCentsEur(transaction.amountCents),
      formatCentsPlain(transaction.amountCents),
    ]) {
      if (field.toLowerCase().contains(needle)) return true;
    }
    return false;
  }

  bool _matchesCategory(Transaction transaction) {
    switch (category.mode) {
      case CategoryFilterMode.all:
        return true;
      case CategoryFilterMode.without:
        // Transfers need no category, so listing them as missing one is noise
        // they would dominate (ticket 049).
        return transaction.categoryUuid == null &&
            transaction.kind != TransactionKind.transfer;
      case CategoryFilterMode.subtree:
        final uuid = transaction.categoryUuid;
        return uuid != null && category.uuids.contains(uuid);
    }
  }
}
