import 'monthly_category_report.dart';

/// Fewer filled months than this and a straight line says nothing.
const minimumForecastMonths = 3;

/// One month of the series, magnitude only — like `CategoryRow`, the direction
/// carries the sign.
class MonthValue {
  const MonthValue({
    required this.year,
    required this.month,
    required this.cents,
  });

  final int year;
  final int month;
  final int cents;

  DateTime get monthStart => DateTime(year, month);
}

class LinearFit {
  const LinearFit({
    required this.slope,
    required this.intercept,
    required this.r2,
  });

  /// Cents per month.
  final double slope;

  /// Cents at `x = 0`, i.e. the first month of the window.
  final double intercept;

  /// Share of the variance the line explains, `0` when there is none to explain.
  final double r2;

  double valueAt(int x) => intercept + slope * x;
}

/// Ordinary least squares over `x = 0 … n−1`.
LinearFit fitLinear(List<int> values) {
  if (values.length < 2) {
    return LinearFit(
      slope: 0,
      intercept: values.isEmpty ? 0 : values.first.toDouble(),
      r2: 0,
    );
  }

  final n = values.length;
  final meanX = (n - 1) / 2;
  var meanY = 0.0;
  for (final value in values) {
    meanY += value;
  }
  meanY /= n;

  var sxx = 0.0;
  var sxy = 0.0;
  for (var x = 0; x < n; x++) {
    final dx = x - meanX;
    sxx += dx * dx;
    sxy += dx * (values[x] - meanY);
  }
  final slope = sxx == 0 ? 0.0 : sxy / sxx;
  final intercept = meanY - slope * meanX;

  var ssTot = 0.0;
  var ssRes = 0.0;
  for (var x = 0; x < n; x++) {
    final dy = values[x] - meanY;
    ssTot += dy * dy;
    final residual = values[x] - (intercept + slope * x);
    ssRes += residual * residual;
  }
  // A flat series has nothing to explain — reporting 1.0 there would read as a
  // perfect fit, and 0/0 would be NaN.
  final r2 = ssTot == 0 ? 0.0 : (1 - ssRes / ssTot).clamp(0.0, 1.0);

  return LinearFit(slope: slope, intercept: intercept, r2: r2);
}

class ForecastResult {
  const ForecastResult({
    required this.history,
    required this.forecast,
    required this.slopeCentsPerMonth,
    required this.interceptCents,
    required this.r2,
  });

  /// Too short a history to fit: the months are still worth showing, the line
  /// is not.
  const ForecastResult.insufficient(this.history)
    : forecast = const [],
      slopeCentsPerMonth = 0,
      interceptCents = 0,
      r2 = 0;

  static const empty = ForecastResult.insufficient(<MonthValue>[]);

  final List<MonthValue> history;
  final List<MonthValue> forecast;
  final double slopeCentsPerMonth;

  /// Value of the fitted line at the first month of the history — the chart
  /// needs both ends to draw it.
  final double interceptCents;
  final double r2;

  bool get hasForecast => forecast.isNotEmpty;

  /// The fitted line at month index [x], counted from the first history month.
  double fittedCentsAt(int x) => interceptCents + slopeCentsPerMonth * x;
}

/// Identifies one forecast, and doubles as the provider family key.
class ForecastFilter {
  const ForecastFilter({
    required this.categoryUuid,
    required this.anchorYear,
    required this.anchorMonth,
    this.accountUuid,
    this.direction = ReportDirection.expenses,
    this.windowMonths = 12,
    this.horizonMonths = 6,
  });

  ForecastFilter.of(
    DateTime anchor, {
    required this.categoryUuid,
    this.accountUuid,
    this.direction = ReportDirection.expenses,
    this.windowMonths = 12,
    this.horizonMonths = 6,
  }) : anchorYear = anchor.year,
       anchorMonth = anchor.month;

  final String categoryUuid;
  final int anchorYear;
  final int anchorMonth;

  /// `null` = all non-archived accounts.
  final String? accountUuid;
  final ReportDirection direction;

  /// `null` = all available history.
  final int? windowMonths;
  final int horizonMonths;

  DateTime get anchor => DateTime(anchorYear, anchorMonth);

  ForecastFilter _copyWith({
    String? categoryUuid,
    Object? accountUuid = _unset,
    ReportDirection? direction,
    Object? windowMonths = _unset,
    int? horizonMonths,
  }) => ForecastFilter(
    categoryUuid: categoryUuid ?? this.categoryUuid,
    anchorYear: anchorYear,
    anchorMonth: anchorMonth,
    accountUuid: accountUuid == _unset
        ? this.accountUuid
        : accountUuid as String?,
    direction: direction ?? this.direction,
    windowMonths: windowMonths == _unset
        ? this.windowMonths
        : windowMonths as int?,
    horizonMonths: horizonMonths ?? this.horizonMonths,
  );

  ForecastFilter withCategory(String value) => _copyWith(categoryUuid: value);

  ForecastFilter withAccount(String? value) => _copyWith(accountUuid: value);

  ForecastFilter withDirection(ReportDirection value) =>
      _copyWith(direction: value);

  ForecastFilter withWindow(int? value) => _copyWith(windowMonths: value);

  ForecastFilter withHorizon(int value) => _copyWith(horizonMonths: value);

  @override
  bool operator ==(Object other) =>
      other is ForecastFilter &&
      other.categoryUuid == categoryUuid &&
      other.anchorYear == anchorYear &&
      other.anchorMonth == anchorMonth &&
      other.accountUuid == accountUuid &&
      other.direction == direction &&
      other.windowMonths == windowMonths &&
      other.horizonMonths == horizonMonths;

  @override
  int get hashCode => Object.hash(
    categoryUuid,
    anchorYear,
    anchorMonth,
    accountUuid,
    direction,
    windowMonths,
    horizonMonths,
  );
}

/// Sentinel so `null` stays a legal value for the nullable copy parameters.
const _unset = Object();
