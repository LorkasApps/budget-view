import 'forecast.dart';
import 'monthly_category_report.dart';
import 'monthly_category_report_service.dart';

/// Projects one category's monthly totals forward with ordinary least squares.
///
/// The history comes from [MonthlyCategoryReportService.computeSeries], so
/// forecast and report can never disagree about what a month was worth: the
/// value per month is that category's `rollupCents`, own plus descendants.
class ForecastService {
  ForecastService(this._reports);

  final MonthlyCategoryReportService _reports;

  Future<ForecastResult> compute({
    required String categoryUuid,
    required DateTime anchorMonth,
    required int? windowMonths,
    required int horizonMonths,
    String? accountUuid,
    required ReportDirection direction,
  }) async {
    final points = await _reports.computeSeries(
      anchorMonth: anchorMonth,
      windowMonths: windowMonths,
      accountUuid: accountUuid,
      direction: direction,
    );
    final history = [
      for (final point in points)
        MonthValue(
          year: point.year,
          month: point.month,
          cents: point.report.rowFor(categoryUuid)?.rollupCents ?? 0,
        ),
    ];
    if (history.length < minimumForecastMonths) {
      return ForecastResult.insufficient(history);
    }

    final fit = fitLinear([for (final value in history) value.cents]);
    final anchor = DateTime(anchorMonth.year, anchorMonth.month);
    final lastIndex = history.length - 1;
    final forecast = <MonthValue>[];
    for (var step = 1; step <= horizonMonths; step++) {
      final month = DateTime(anchor.year, anchor.month + step);
      final projected = fit.valueAt(lastIndex + step);
      forecast.add(
        MonthValue(
          year: month.year,
          month: month.month,
          // A falling trend runs through zero eventually; negative spending is
          // not a thing, so the projection floors there.
          cents: projected < 0 ? 0 : projected.round(),
        ),
      );
    }

    return ForecastResult(
      history: history,
      forecast: forecast,
      slopeCentsPerMonth: fit.slope,
      interceptCents: fit.intercept,
      r2: fit.r2,
    );
  }
}
