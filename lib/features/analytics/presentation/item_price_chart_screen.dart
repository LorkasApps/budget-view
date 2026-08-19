import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/money/money.dart';
import '../domain/analytics_providers.dart';
import '../domain/item_price_trend.dart';

/// Unit price of one item over time, one dot per purchase.
///
/// Reached from the search list or by long-pressing the position itself, which
/// is why the raw spelling travels in as [title]: the normalized key is a
/// lookup value, not something to show.
class ItemPriceChartScreen extends ConsumerWidget {
  const ItemPriceChartScreen({
    super.key,
    required this.normalizedKey,
    required this.title,
  });

  final String normalizedKey;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ref.watch(itemPriceSeriesProvider(normalizedKey)).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _Hint('Preisverlauf nicht ladbar: $error'),
      data: (series) {
        if (series.isEmpty) return const _Hint('Keine Käufe erfasst');
        if (series.count == 1) {
          final price = formatCentsEur(series.points.single.unitPriceCents);
          return _Hint('Nur ein Datenpunkt ($price) — kein Trend darstellbar');
        }
        return _PriceChart(series: series);
      },
    ),
  );
}

class _PriceChart extends StatelessWidget {
  const _PriceChart({required this.series});

  final ItemPriceSeries series;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final points = series.points;
    final minCents = series.minUnitPriceCents!;
    final maxCents = series.maxUnitPriceCents!;
    final flat = minCents == maxCents;

    // x = days since the first purchase, so an eight-week gap reads as one.
    // An index axis would space irregular purchases evenly and invent a trend.
    final firstDate = points.first.date;
    final spots = [
      for (final point in points)
        FlSpot(
          point.date.difference(firstDate).inDays.toDouble(),
          point.unitPriceCents / 100,
        ),
    ];
    // Everything bought on one day would collapse the axis to a single tick.
    final maxX = spots.last.x == 0 ? 1.0 : spots.last.x;

    // Unlike the forecast this chart does not anchor at zero: a 20-cent move on
    // a 1,49 € item is the whole story and would be invisible next to the axis.
    final low = minCents / 100;
    final high = maxCents / 100;
    final padding = flat ? _flatPadding(high) : (high - low) * 0.15;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SizedBox(
          height: 260,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 24, 24, 8),
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: (low - padding).clamp(0.0, double.infinity),
                maxY: high + padding,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 48,
                      getTitlesWidget: (value, meta) => Text(
                        value.toStringAsFixed(2).replaceAll('.', ','),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      // Only the two ends get a tick; every purchase in between
                      // would overlap on a narrow phone.
                      interval: maxX,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          formatDateDe(
                            value <= 0 ? firstDate : points.last.date,
                          ),
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: flat
                      ? [
                          _marker(
                            cents: maxCents,
                            text: 'Preis ${formatCentsEur(maxCents)}',
                            color: scheme.outline,
                            alignment: Alignment.topRight,
                          ),
                        ]
                      : [
                          _marker(
                            cents: maxCents,
                            text: 'Max ${formatCentsEur(maxCents)}',
                            color: scheme.error,
                            alignment: Alignment.topRight,
                          ),
                          _marker(
                            cents: minCents,
                            text: 'Min ${formatCentsEur(minCents)}',
                            color: scheme.primary,
                            alignment: Alignment.bottomRight,
                          ),
                        ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    barWidth: 2,
                    color: scheme.primary,
                    dotData: FlDotData(
                      getDotPainter: (spot, percent, bar, index) {
                        final cents = points[index].unitPriceCents;
                        final extreme =
                            !flat &&
                            (cents == minCents || cents == maxCents);
                        return FlDotCirclePainter(
                          radius: extreme ? 5 : 3,
                          color: cents == maxCents && extreme
                              ? scheme.error
                              : scheme.primary,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.shopping_basket_outlined),
          title: Text('${points.length} Käufe erfasst'),
          subtitle: Text(
            'Zuletzt ${formatCentsEur(points.last.unitPriceCents)} '
            'am ${formatDateDe(points.last.date)}',
          ),
        ),
      ],
    );
  }

  /// A flat series has no spread to derive a margin from.
  static double _flatPadding(double value) => value == 0 ? 1 : value * 0.1;

  static HorizontalLine _marker({
    required int cents,
    required String text,
    required Color color,
    required Alignment alignment,
  }) => HorizontalLine(
    y: cents / 100,
    color: color,
    strokeWidth: 1,
    dashArray: const [4, 4],
    label: HorizontalLineLabel(
      show: true,
      alignment: alignment,
      style: TextStyle(fontSize: 10, color: color),
      labelResolver: (_) => text,
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(child: Text(text, textAlign: TextAlign.center)),
  );
}
