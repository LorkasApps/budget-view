import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/money.dart';
import '../../account/domain/account_providers.dart';
import '../../category/presentation/category_chip.dart';
import '../../category/presentation/category_picker.dart';
import '../domain/analytics_providers.dart';
import '../domain/forecast.dart';
import '../domain/monthly_category_report.dart';
import 'account_filter_sheet.dart';

/// Linear projection of one category's monthly totals.
///
/// Reached either from the shell's own tab (no [initialFilter] — the user picks
/// a category first) or from a report row, which hands over category, account,
/// direction and its month so both screens describe the same numbers.
class ForecastScreen extends ConsumerStatefulWidget {
  const ForecastScreen({super.key, this.initialFilter});

  final ForecastFilter? initialFilter;

  @override
  ConsumerState<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends ConsumerState<ForecastScreen> {
  ForecastFilter? _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  Future<void> _pickCategory() async {
    final pick = await pickCategory(
      context,
      selected: _filter?.categoryUuid,
      allowNone: false,
    );
    final uuid = pick?.uuid;
    if (uuid == null) return;
    setState(() {
      _filter =
          _filter?.withCategory(uuid) ??
          ForecastFilter.of(DateTime.now(), categoryUuid: uuid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = _filter;
    return Scaffold(
      appBar: AppBar(title: const Text('Prognose')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _Controls(
            filter: filter,
            onPickCategory: _pickCategory,
            onChanged: (next) => setState(() => _filter = next),
          ),
          const Divider(height: 1),
          if (filter == null)
            const _Hint('Kategorie wählen, um eine Prognose zu sehen')
          else
            ref
                .watch(forecastProvider(filter))
                .when(
                  data: (result) => result.hasForecast
                      ? _ForecastBody(result: result)
                      : const _Hint(
                          'Zu wenige Daten für Prognose '
                          '(mindestens 3 Monate)',
                        ),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => _Hint('Prognose nicht berechenbar: $error'),
                ),
        ],
      ),
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({
    required this.filter,
    required this.onPickCategory,
    required this.onChanged,
  });

  final ForecastFilter? filter;
  final VoidCallback onPickCategory;
  final ValueChanged<ForecastFilter> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider(false)).valueOrNull ?? const [];
    var accountLabel = 'Alle Konten';
    for (final account in accounts) {
      if (account.uuid == filter?.accountUuid) accountLabel = account.name;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (filter == null)
                ActionChip(
                  avatar: const Icon(Icons.category_outlined, size: 18),
                  label: const Text('Kategorie wählen'),
                  onPressed: onPickCategory,
                )
              else
                CategoryChip(
                  categoryUuid: filter!.categoryUuid,
                  onTap: onPickCategory,
                ),
              ActionChip(
                avatar: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                ),
                label: Text(accountLabel),
                onPressed: filter == null
                    ? null
                    : () async {
                        final pick = await pickAccount(
                          context,
                          selected: filter!.accountUuid,
                        );
                        if (pick != null) {
                          onChanged(filter!.withAccount(pick.accountUuid));
                        }
                      },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<ReportDirection>(
            segments: const [
              ButtonSegment(
                value: ReportDirection.expenses,
                label: Text('Ausgaben'),
              ),
              ButtonSegment(
                value: ReportDirection.income,
                label: Text('Einnahmen'),
              ),
            ],
            selected: {filter?.direction ?? ReportDirection.expenses},
            onSelectionChanged: filter == null
                ? null
                : (selection) => onChanged(filter!.withDirection(selection.first)),
          ),
          const SizedBox(height: 8),
          _ChoiceRow(
            label: 'Fenster',
            options: const [
              ('3', 3),
              ('6', 6),
              ('12', 12),
              ('Alle', null),
            ],
            selected: filter?.windowMonths,
            onSelected: filter == null
                ? null
                : (value) => onChanged(filter!.withWindow(value)),
          ),
          _ChoiceRow(
            label: 'Horizont',
            options: const [
              ('3', 3),
              ('6', 6),
              ('12', 12),
            ],
            selected: filter?.horizonMonths,
            onSelected: filter == null
                ? null
                : (value) => onChanged(filter!.withHorizon(value!)),
          ),
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<(String, int?)> options;
  final int? selected;
  final ValueChanged<int?>? onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(
        width: 80,
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
      Expanded(
        child: Wrap(
          spacing: 8,
          children: [
            for (final (text, value) in options)
              ChoiceChip(
                label: Text(text),
                selected: selected == value,
                onSelected: onSelected == null
                    ? null
                    : (_) => onSelected!(value),
              ),
          ],
        ),
      ),
    ],
  );
}

class _ForecastBody extends StatelessWidget {
  const _ForecastBody({required this.result});

  final ForecastResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final history = result.history;
    final forecast = result.forecast;
    final lastHistoryIndex = history.length - 1;

    final historySpots = [
      for (var i = 0; i < history.length; i++)
        FlSpot(i.toDouble(), history[i].cents / 100),
    ];
    // The dashed run starts on the last measured point, otherwise it floats.
    final forecastSpots = [
      FlSpot(lastHistoryIndex.toDouble(), history.last.cents / 100),
      for (var i = 0; i < forecast.length; i++)
        FlSpot((lastHistoryIndex + 1 + i).toDouble(), forecast[i].cents / 100),
    ];
    final fitSpots = [
      FlSpot(0, result.fittedCentsAt(0) / 100),
      FlSpot(lastHistoryIndex.toDouble(), result.fittedCentsAt(lastHistoryIndex) / 100),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 240,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            child: LineChart(
              LineChartData(
                minY: 0,
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
                        value.round().toString(),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        final label = _monthLabel(index, history, forecast);
                        if (label == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            label,
                            style: const TextStyle(fontSize: 9),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: fitSpots,
                    isCurved: false,
                    barWidth: 1,
                    color: scheme.outline,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: historySpots,
                    isCurved: false,
                    barWidth: 2,
                    color: scheme.primary,
                  ),
                  LineChartBarData(
                    spots: forecastSpots,
                    isCurved: false,
                    barWidth: 2,
                    color: scheme.tertiary,
                    dashArray: const [6, 4],
                  ),
                ],
              ),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.trending_up),
          title: Text(
            'Trend ${_signedEur(result.slopeCentsPerMonth)} pro Monat',
          ),
          subtitle: Text('Anpassungsgüte ${(result.r2 * 100).round()} %'),
        ),
        const Divider(height: 1),
        for (final value in forecast)
          ListTile(
            dense: true,
            title: Text(_monthYearLabel(value)),
            trailing: Text(formatCentsEur(value.cents)),
          ),
      ],
    );
  }

  static String? _monthLabel(
    int index,
    List<MonthValue> history,
    List<MonthValue> forecast,
  ) {
    final all = [...history, ...forecast];
    if (index < 0 || index >= all.length) return null;
    final value = all[index];
    final month = value.month.toString().padLeft(2, '0');
    return '$month.${value.year % 100}';
  }

  static String _monthYearLabel(MonthValue value) {
    final month = value.month.toString().padLeft(2, '0');
    return '$month/${value.year}';
  }

  static String _signedEur(double cents) {
    final rounded = cents.round();
    final sign = rounded > 0 ? '+' : '';
    return '$sign${formatCentsEur(rounded)}';
  }
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
