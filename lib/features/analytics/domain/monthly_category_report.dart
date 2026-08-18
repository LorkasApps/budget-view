/// Which half of the bookings a report covers. The split follows the sign of
/// the booking, never the placement of its category (see decisions.md).
enum ReportDirection { expenses, income }

/// Identifies one report. Doubles as the family key of
/// `monthlyCategoryReportProvider`, hence the value equality.
class MonthlyReportFilter {
  const MonthlyReportFilter({
    required this.year,
    required this.month,
    this.accountUuid,
    this.direction = ReportDirection.expenses,
  });

  MonthlyReportFilter.of(
    DateTime month, {
    this.accountUuid,
    this.direction = ReportDirection.expenses,
  }) : year = month.year,
       month = month.month;

  final int year;
  final int month;

  /// `null` = all non-archived accounts.
  final String? accountUuid;
  final ReportDirection direction;

  DateTime get monthStart => DateTime(year, month);

  MonthlyReportFilter shiftMonths(int delta) => MonthlyReportFilter.of(
    DateTime(year, month + delta),
    accountUuid: accountUuid,
    direction: direction,
  );

  MonthlyReportFilter withMonth(DateTime value) => MonthlyReportFilter.of(
    value,
    accountUuid: accountUuid,
    direction: direction,
  );

  MonthlyReportFilter withAccount(String? value) => MonthlyReportFilter(
    year: year,
    month: month,
    accountUuid: value,
    direction: direction,
  );

  MonthlyReportFilter withDirection(ReportDirection value) =>
      MonthlyReportFilter(
        year: year,
        month: month,
        accountUuid: accountUuid,
        direction: value,
      );

  @override
  bool operator ==(Object other) =>
      other is MonthlyReportFilter &&
      other.year == year &&
      other.month == month &&
      other.accountUuid == accountUuid &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(year, month, accountUuid, direction);
}

/// One month of a series. The month travels next to the report rather than
/// inside it, so [MonthlyCategoryReport.empty] can stay `const`.
class MonthlyReportPoint {
  const MonthlyReportPoint({
    required this.year,
    required this.month,
    required this.report,
  });

  final int year;
  final int month;
  final MonthlyCategoryReport report;

  DateTime get monthStart => DateTime(year, month);
}

/// One category's share of a month. All amounts are magnitudes — the direction
/// already carries the sign.
class CategoryRow {
  const CategoryRow({
    required this.categoryUuid,
    required this.name,
    required this.iconName,
    required this.colorHex,
    required this.ownCents,
    required this.rollupCents,
    required this.depth,
    required this.parentCategoryUuid,
  });

  final String categoryUuid;
  final String name;
  final String iconName;
  final String colorHex;

  /// Units assigned to this category itself, without descendants.
  final int ownCents;

  /// [ownCents] plus every descendant's own amounts.
  final int rollupCents;

  final int depth;

  /// Parent within the built tree — `null` for a row rendered at top level. A
  /// category whose parent row is missing (parent hard-gone) is promoted here
  /// too, so no amount can hide below an absent node.
  final String? parentCategoryUuid;
}

class MonthlyCategoryReport {
  const MonthlyCategoryReport({
    required this.rows,
    required this.uncategorizedCents,
    required this.totalCents,
  });

  static const empty = MonthlyCategoryReport(
    rows: [],
    uncategorizedCents: 0,
    totalCents: 0,
  );

  /// Every category carrying a non-zero rollup, sorted by [rollupCents] DESC.
  /// Flat on purpose: the screen slices it by [childrenOf] per drilldown level.
  final List<CategoryRow> rows;

  /// Units whose effective category is null — or points at a category that no
  /// longer exists. Kept out of the donut composition.
  final int uncategorizedCents;

  /// Everything in scope, including [uncategorizedCents].
  final int totalCents;

  bool get isEmpty => rows.isEmpty && totalCents == 0;

  int get categorizedCents => totalCents - uncategorizedCents;

  List<CategoryRow> childrenOf(String? parentCategoryUuid) => [
    for (final row in rows)
      if (row.parentCategoryUuid == parentCategoryUuid) row,
  ];

  bool hasChildren(String categoryUuid) =>
      rows.any((row) => row.parentCategoryUuid == categoryUuid);

  CategoryRow? rowFor(String categoryUuid) {
    for (final row in rows) {
      if (row.categoryUuid == categoryUuid) return row;
    }
    return null;
  }
}
