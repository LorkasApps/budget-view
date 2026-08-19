import '../../../core/text/normalize.dart';
import '../../account/domain/account_repository.dart';
import '../../drilldown/data/line_item.dart';
import '../../drilldown/domain/line_item_repository.dart';
import '../../transaction/domain/transaction_repository.dart';
import 'item_price_trend.dart';

/// Price history per item, sourced from positions across all bookings.
///
/// Grouping key is the normalized description, shared with dedupe and tagging
/// (`normalizeForMatching`), so "the same item" means the same thing in all
/// three places. Bookings without positions contribute nothing: a booking total
/// is not an item price.
class ItemPriceTrendService {
  ItemPriceTrendService(this._transactions, this._lineItems, this._accounts);

  final TransactionRepository _transactions;
  final LineItemRepository _lineItems;
  final AccountRepository _accounts;

  /// Groups whose key contains [query] (normalized), most-bought first.
  ///
  /// An empty query returns nothing rather than the whole catalogue — the
  /// screen asks for a search, and the full list would be its own feature.
  Future<List<ItemGroup>> searchGroups(String query) async {
    final needle = normalizeForMatching(query);
    if (needle.isEmpty) return const [];

    final byKey = await _pointsByKey();
    final groups = <ItemGroup>[];
    for (final entry in byKey.entries) {
      if (!entry.key.contains(needle)) continue;
      final points = entry.value;
      groups.add(
        ItemGroup(
          normalizedKey: entry.key,
          label: points.last.label,
          purchaseCount: points.length,
          latestUnitPriceCents: points.last.unitPriceCents,
          latestDate: points.last.date,
        ),
      );
    }

    groups.sort((a, b) {
      final byCount = b.purchaseCount.compareTo(a.purchaseCount);
      return byCount != 0 ? byCount : a.label.compareTo(b.label);
    });
    return groups;
  }

  /// Every purchase of one group, oldest first.
  Future<ItemPriceSeries> series(String normalizedKey) async {
    final key = normalizeForMatching(normalizedKey);
    final points = (await _pointsByKey())[key];
    if (points == null) return ItemPriceSeries.emptyFor(key);

    return ItemPriceSeries(
      normalizedKey: key,
      label: points.last.label,
      points: [
        for (final point in points)
          PricePoint(date: point.date, unitPriceCents: point.unitPriceCents),
      ],
    );
  }

  /// All positions of all non-archived accounts, bucketed by normalized
  /// description and sorted by purchase date.
  Future<Map<String, List<_Purchase>>> _pointsByKey() async {
    final bookingDates = <String, DateTime>{};
    for (final account in await _accounts.findAll()) {
      for (final booking in await _transactions.findByAccount(account.uuid)) {
        bookingDates[booking.uuid] = booking.bookingDate;
      }
    }
    if (bookingDates.isEmpty) return const {};

    final items = await _lineItems.findByTransactions(
      bookingDates.keys.toList(),
    );

    final byKey = <String, List<_Purchase>>{};
    for (final item in items) {
      // The managed row is the difference to the booking total, not an item.
      if (item.kind == LineItemKind.restposten) continue;
      // No empty-key guard: the repository validates the description as
      // non-blank on every write, so a normalized key is always matchable.
      final key = normalizeForMatching(item.description);
      final date = bookingDates[item.transactionUuid];
      if (date == null) continue;

      byKey.putIfAbsent(key, () => []).add(
        _Purchase(
          date: date,
          unitPriceCents: _unitPriceCents(item),
          label: item.description.trim(),
        ),
      );
    }

    for (final points in byKey.values) {
      points.sort((a, b) => a.date.compareTo(b.date));
    }
    return byKey;
  }

  /// Printed unit price if there is one, else derived from the amount.
  ///
  /// `LineItem.amountCents` is non-nullable and never 0, so a position always
  /// yields a price; without a quantity the amount *is* the unit price.
  static int _unitPriceCents(LineItem item) {
    final printed = item.unitPriceCents;
    if (printed != null) return printed;

    final amount = item.amountCents.abs();
    final quantity = item.quantity;
    if (quantity != null && quantity > 0) return (amount / quantity).round();
    return amount;
  }
}

/// A point plus the spelling it was booked under, which the group label needs.
class _Purchase {
  const _Purchase({
    required this.date,
    required this.unitPriceCents,
    required this.label,
  });

  final DateTime date;
  final int unitPriceCents;
  final String label;
}
