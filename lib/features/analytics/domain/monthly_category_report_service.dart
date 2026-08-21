import '../../account/domain/account_repository.dart';
import '../../category/data/category.dart';
import '../../category/domain/category_repository.dart';
import '../../category/domain/category_tree.dart';
import '../../drilldown/data/line_item.dart';
import '../../drilldown/domain/category_resolver.dart';
import '../../drilldown/domain/line_item_repository.dart';
import '../../transaction/data/transaction.dart';
import '../../transaction/domain/transaction_repository.dart';
import 'monthly_category_report.dart';

/// Aggregates bookings into the category tree, one month at a time.
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
    final series = await computeSeries(
      anchorMonth: DateTime(year, month),
      windowMonths: 1,
      accountUuid: accountUuid,
      direction: direction,
    );
    return series.isEmpty ? MonthlyCategoryReport.empty : series.first.report;
  }

  /// The months `[anchor − (windowMonths − 1) … anchor]`, oldest first. A
  /// `null` window starts at the first month that has anything in scope, and
  /// yields nothing at all when there is no such month.
  ///
  /// Months without bookings are present as [MonthlyCategoryReport.empty]: the
  /// forecast needs a contiguous series, and a gap is a real zero.
  ///
  /// Bookings, positions and the category tree are each loaded once for the
  /// whole span — the per-month loop only re-aggregates.
  Future<List<MonthlyReportPoint>> computeSeries({
    required DateTime anchorMonth,
    required int? windowMonths,
    String? accountUuid,
    required ReportDirection direction,
  }) async {
    assert(windowMonths == null || windowMonths > 0);
    final anchor = DateTime(anchorMonth.year, anchorMonth.month);
    final afterAnchor = DateTime(anchor.year, anchor.month + 1);

    final bookings = <Transaction>[];
    if (accountUuid != null) {
      bookings.addAll(await _transactions.findByAccount(accountUuid));
    } else {
      for (final account in await _accounts.findAll()) {
        bookings.addAll(await _transactions.findByAccount(account.uuid));
      }
    }
    final directional = [
      for (final booking in bookings)
        // Transfers move money between the user's own accounts, so they are
        // neither spending nor income and belong in no total (ticket 032).
        if (booking.kind != TransactionKind.transfer &&
            booking.bookingDate.isBefore(afterAnchor) &&
            _matchesDirection(booking.amountCents, direction))
          booking,
    ];

    final DateTime start;
    if (windowMonths != null) {
      start = DateTime(anchor.year, anchor.month - (windowMonths - 1));
    } else {
      DateTime? earliest;
      for (final booking in directional) {
        if (earliest == null || booking.bookingDate.isBefore(earliest)) {
          earliest = booking.bookingDate;
        }
      }
      if (earliest == null) return const [];
      start = DateTime(earliest.year, earliest.month);
    }

    final inScope = [
      for (final booking in directional)
        if (!booking.bookingDate.isBefore(start)) booking,
    ];
    final byMonth = <int, List<Transaction>>{};
    for (final booking in inScope) {
      final key = _monthKey(booking.bookingDate.year, booking.bookingDate.month);
      (byMonth[key] ??= []).add(booking);
    }

    final positions = await _lineItems.findByTransactions([
      for (final booking in inScope) booking.uuid,
    ]);
    final byBooking = <String, List<LineItem>>{};
    for (final position in positions) {
      (byBooking[position.transactionUuid] ??= []).add(position);
    }

    final categories = await _categories.findAll(includeArchived: true);
    final known = {for (final category in categories) category.uuid: category};
    final roots = buildCategoryTree(categories);

    final points = <MonthlyReportPoint>[];
    var cursor = start;
    while (!cursor.isAfter(anchor)) {
      final monthBookings = byMonth[_monthKey(cursor.year, cursor.month)];
      points.add(
        MonthlyReportPoint(
          year: cursor.year,
          month: cursor.month,
          report: monthBookings == null
              ? MonthlyCategoryReport.empty
              : _reportFrom(monthBookings, byBooking, roots, known),
        ),
      );
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return points;
  }

  MonthlyCategoryReport _reportFrom(
    List<Transaction> bookings,
    Map<String, List<LineItem>> positionsByBooking,
    List<CategoryNode> roots,
    Map<String, Category> known,
  ) {
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

    for (final booking in bookings) {
      final items = positionsByBooking[booking.uuid];
      if (items == null || items.isEmpty) {
        addUnit(booking.categoryUuid, booking.amountCents);
        continue;
      }
      for (final item in items) {
        addUnit(effectiveCategoryUuid(item, booking), item.amountCents);
      }
    }

    final rows = <CategoryRow>[];
    for (final root in roots) {
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

  static int _monthKey(int year, int month) => year * 12 + month;
}
