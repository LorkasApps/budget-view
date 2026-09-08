/// Identifies one result figure: income against expenses, which the report's
/// direction filter can never show because it only ever shows one of the two.
///
/// A `null` [month] means the whole calendar year. Doubles as the family key of
/// `resultSeriesProvider`, hence the value equality.
class ResultFilter {
  const ResultFilter({required this.year, this.month, this.accountUuid});

  final int year;

  /// `null` = the whole calendar year.
  final int? month;

  /// `null` = all non-archived accounts.
  final String? accountUuid;

  bool get isYear => month == null;

  /// Youngest month of the span — `computeSeries` counts backwards from here.
  DateTime get anchorMonth => DateTime(year, month ?? 12);

  int get windowMonths => month == null ? 12 : 1;

  ResultFilter withAccount(String? value) =>
      ResultFilter(year: year, month: month, accountUuid: value);

  @override
  bool operator ==(Object other) =>
      other is ResultFilter &&
      other.year == year &&
      other.month == month &&
      other.accountUuid == accountUuid;

  @override
  int get hashCode => Object.hash(year, month, accountUuid);
}

/// One month's two directions side by side.
class MonthResult {
  const MonthResult({
    required this.year,
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
  });

  final int year;
  final int month;

  /// Magnitude, as the report reports it.
  final int incomeCents;

  /// Magnitude too — so the subtraction below is what makes the sign.
  final int expenseCents;

  int get netCents => incomeCents - expenseCents;

  DateTime get monthStart => DateTime(year, month);
}

/// The months of one span, oldest first. Its three getters aggregate the
/// points, so a single-month series answers with that month's own figures —
/// month mode and year mode read the same three numbers through the same path
/// and cannot disagree.
class ResultSeries {
  const ResultSeries(this.points);

  static const empty = ResultSeries(<MonthResult>[]);

  final List<MonthResult> points;

  int get incomeCents => _sum((point) => point.incomeCents);

  int get expenseCents => _sum((point) => point.expenseCents);

  int get netCents => incomeCents - expenseCents;

  int _sum(int Function(MonthResult point) value) =>
      points.fold(0, (sum, point) => sum + value(point));
}
