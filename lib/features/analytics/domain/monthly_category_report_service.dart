import '../../account/domain/account_repository.dart';
import '../../category/domain/category_repository.dart';
import '../../category/domain/category_tree.dart';
import '../../drilldown/data/line_item.dart';
import '../../drilldown/domain/category_resolver.dart';
import '../../drilldown/domain/line_item_repository.dart';
import '../../transaction/data/transaction.dart';
import '../../transaction/domain/transaction_repository.dart';
import 'monthly_category_report.dart';

/// Aggregates one month of bookings into the category tree.
///
/// The smallest unit is a position when the booking has any, otherwise the
/// booking itself — and a position's category always comes from
/// [effectiveCategoryUuid], never from `LineItem.categoryUuid` directly, so the
/// fractal rule cannot drift between call sites (see drilldown.md).
class MonthlyCategoryReportService {
  MonthlyCategoryReportService(
    this._transactions,
    this._lineItems,
    this._categories,
    this._accounts,
  );

  final TransactionRepository _transactions;
  final LineItemRepository _lineItems;
  final CategoryRepository _categories;
  final AccountRepository _accounts;

  Future<MonthlyCategoryReport> compute({
    required int year,
    required int month,
    String? accountUuid,
    required ReportDirection direction,
  }) async {
    final monthStart = DateTime(year, month);
    final nextMonthStart = DateTime(year, month + 1);

    final bookings = <Transaction>[];
    if (accountUuid != null) {
      bookings.addAll(await _transactions.findByAccount(accountUuid));
    } else {
      for (final account in await _accounts.findAll()) {
        bookings.addAll(await _transactions.findByAccount(account.uuid));
      }
    }

    final inScope = [
      for (final booking in bookings)
        if (!booking.bookingDate.isBefore(monthStart) &&
            booking.bookingDate.isBefore(nextMonthStart) &&
            _matchesDirection(booking.amountCents, direction))
          booking,
    ];
    if (inScope.isEmpty) return MonthlyCategoryReport.empty;

    final positions = await _lineItems.findByTransactions([
      for (final booking in inScope) booking.uuid,
    ]);
    final byBooking = <String, List<LineItem>>{};
    for (final position in positions) {
      (byBooking[position.transactionUuid] ??= []).add(position);
    }

    final categories = await _categories.findAll(includeArchived: true);
    final known = {for (final category in categories) category.uuid: category};

    final ownCents = <String, int>{};
    var uncategorizedCents = 0;
    var totalCents = 0;

    void addUnit(String? categoryUuid, int amountCents) {
      totalCents += amountCents;
      if (categoryUuid == null || !known.containsKey(categoryUuid)) {
        uncategorizedCents += amountCents;
        return;
      }
      ownCents[categoryUuid] = (ownCents[categoryUuid] ?? 0) + amountCents;
    }

    for (final booking in inScope) {
      final items = byBooking[booking.uuid];
      if (items == null || items.isEmpty) {
        addUnit(booking.categoryUuid, booking.amountCents);
        continue;
      }
      for (final item in items) {
        addUnit(effectiveCategoryUuid(item, booking), item.amountCents);
      }
    }

    final rows = <CategoryRow>[];
    for (final root in buildCategoryTree(categories)) {
      _collect(root, ownCents, null, rows);
    }
    rows.sort((a, b) => b.rollupCents.compareTo(a.rollupCents));

    return MonthlyCategoryReport(
      rows: rows,
      uncategorizedCents: uncategorizedCents.abs(),
      totalCents: totalCents.abs(),
    );
  }

  /// Appends [node]'s row (when it carries anything) plus its descendants' and
  /// returns the subtree's signed sum.
  int _collect(
    CategoryNode node,
    Map<String, int> ownCents,
    String? parentCategoryUuid,
    List<CategoryRow> out,
  ) {
    final own = ownCents[node.category.uuid] ?? 0;
    final rowsBefore = out.length;
    var rollup = own;
    for (final child in node.children) {
      rollup += _collect(child, ownCents, node.category.uuid, out);
    }
    // A parent netting to zero still needs its row while a descendant has one,
    // or that descendant would have no level to be listed on.
    if (own != 0 || rollup != 0 || out.length > rowsBefore) {
      out.add(_rowFor(node, parentCategoryUuid, own, rollup));
    }
    return rollup;
  }

  CategoryRow _rowFor(
    CategoryNode node,
    String? parentCategoryUuid,
    int own,
    int rollup,
  ) {
    final category = node.category;
    return CategoryRow(
      categoryUuid: category.uuid,
      name: category.name,
      iconName: category.iconName,
      colorHex: category.colorHex,
      ownCents: own.abs(),
      rollupCents: rollup.abs(),
      depth: node.depth,
      parentCategoryUuid: parentCategoryUuid,
    );
  }

  bool _matchesDirection(int amountCents, ReportDirection direction) =>
      switch (direction) {
        ReportDirection.expenses => amountCents < 0,
        ReportDirection.income => amountCents > 0,
      };
}
