import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../core/money/money.dart';
import '../../account/domain/account_providers.dart';
import '../../category/presentation/category_style.dart';
import '../domain/analytics_providers.dart';
import '../domain/forecast.dart';
import '../domain/monthly_category_report.dart';
import 'account_filter_sheet.dart';
import 'forecast_screen.dart';

/// Month → category breakdown, donut on top and the same numbers as a table
/// beneath. Owns the filter state; drilldowns inherit it unchanged.
class MonthlyCategoryReportScreen extends ConsumerStatefulWidget {
  const MonthlyCategoryReportScreen({super.key});

  @override
  ConsumerState<MonthlyCategoryReportScreen> createState() =>
      _MonthlyCategoryReportScreenState();
}

class _MonthlyCategoryReportScreenState
    extends ConsumerState<MonthlyCategoryReportScreen> {
  MonthlyReportFilter _filter = MonthlyReportFilter.of(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(monthlyCategoryReportProvider(_filter));
    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: Column(
        children: [
          _FilterBar(
            filter: _filter,
            onChanged: (filter) => setState(() => _filter = filter),
          ),
          const Divider(height: 1),
          Expanded(
            child: report.when(
              data: (data) => data.isEmpty
                  ? _EmptyState(filter: _filter)
                  : ReportLevelView(
                      report: data,
                      filter: _filter,
                      parentUuid: null,
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Report nicht berechenbar: $error'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One level of the report: the donut plus the table below it. Reused verbatim
/// by [CategorySubtreeReportScreen], which only passes a different [parentUuid].
class ReportLevelView extends StatelessWidget {
  const ReportLevelView({
    super.key,
    required this.report,
    required this.filter,
    required this.parentUuid,
  });

  final MonthlyCategoryReport report;
  final MonthlyReportFilter filter;

  /// `null` renders the top level, a uuid renders that category's children.
  final String? parentUuid;

  @override
  Widget build(BuildContext context) {
    final parent = parentUuid == null ? null : report.rowFor(parentUuid!);
    final slices = <_Slice>[
      if (parent != null && parent.ownCents > 0)
        _Slice(
          name: '${parent.name} (direkt)',
          iconName: parent.iconName,
          colorHex: parent.colorHex,
          cents: parent.ownCents,
          categoryUuid: null,
          drilldownUuid: null,
        ),
      for (final row in report.childrenOf(parentUuid))
        _Slice(
          name: row.name,
          iconName: row.iconName,
          colorHex: row.colorHex,
          cents: row.rollupCents,
          categoryUuid: row.categoryUuid,
          drilldownUuid: report.hasChildren(row.categoryUuid)
              ? row.categoryUuid
              : null,
        ),
    ];
    final sliceTotal = slices.fold<int>(0, (sum, slice) => sum + slice.cents);
    final uncategorized = parentUuid == null ? report.uncategorizedCents : 0;
    final total = parent?.rollupCents ?? report.totalCents;
    final emphasis = Theme.of(context).textTheme.titleMedium;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (slices.isNotEmpty)
          SizedBox(
            height: 220,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 52,
                  sections: [
                    for (final slice in slices)
                      PieChartSectionData(
                        value: slice.cents.toDouble(),
                        color: categoryColor(slice.colorHex),
                        radius: 46,
                        title: _shareTitle(slice.cents, sliceTotal),
                        titleStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ListTile(
          title: Text('Gesamt', style: emphasis),
          trailing: Text(formatCentsEur(total), style: emphasis),
        ),
        const Divider(height: 1),
        if (uncategorized > 0) _UncategorizedTile(cents: uncategorized),
        for (final slice in slices)
          _SliceTile(
            slice: slice,
            share: sliceTotal == 0 ? 0 : slice.cents / sliceTotal,
            onTap: slice.drilldownUuid == null
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CategorySubtreeReportScreen(
                        filter: filter,
                        categoryUuid: slice.drilldownUuid!,
                      ),
                    ),
                  ),
            // Long-press for the forecast, following the category tree's
            // long-press-to-archive: a third trailing widget next to amount and
            // chevron overflows the row.
            onLongPress: slice.categoryUuid == null
                ? null
                : () => openForecast(
                    context,
                    reportFilter: filter,
                    categoryUuid: slice.categoryUuid!,
                  ),
          ),
      ],
    );
  }

  /// Opens the forecast with everything the report already knows, so the two
  /// screens cannot disagree about the numbers behind one category.
  static void openForecast(
    BuildContext context, {
    required MonthlyReportFilter reportFilter,
    required String categoryUuid,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ForecastScreen(
        initialFilter: ForecastFilter(
          categoryUuid: categoryUuid,
          anchorYear: reportFilter.year,
          anchorMonth: reportFilter.month,
          accountUuid: reportFilter.accountUuid,
          direction: reportFilter.direction,
        ),
      ),
    ),
  );

  /// Slices under 8 % stay unlabelled — the text would not fit the arc.
  static String _shareTitle(int cents, int total) {
    if (total == 0) return '';
    final percent = cents / total * 100;
    return percent < 8 ? '' : '${percent.round()} %';
  }
}

/// Children of one category, same layout as the top level. The filter it was
/// pushed with is fixed here, so both levels always describe the same month.
class CategorySubtreeReportScreen extends ConsumerWidget {
  const CategorySubtreeReportScreen({
    super.key,
    required this.filter,
    required this.categoryUuid,
  });

  final MonthlyReportFilter filter;
  final String categoryUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(monthlyCategoryReportProvider(filter));
    final row = report.valueOrNull?.rowFor(categoryUuid);
    final direction = filter.direction == ReportDirection.expenses
        ? 'Ausgaben'
        : 'Einnahmen';
    return Scaffold(
      appBar: AppBar(
        title: Text(row?.name ?? 'Kategorie'),
        actions: [
          IconButton(
            tooltip: 'Prognose',
            icon: const Icon(Icons.trending_up),
            onPressed: () => ReportLevelView.openForecast(
              context,
              reportFilter: filter,
              categoryUuid: categoryUuid,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${formatMonthYearDe(filter.year, filter.month)} · $direction',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
      body: report.when(
        data: (data) => data.rowFor(categoryUuid) == null
            ? _EmptyState(filter: filter)
            : ReportLevelView(
                report: data,
                filter: filter,
                parentUuid: categoryUuid,
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Report nicht berechenbar: $error')),
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.filter, required this.onChanged});

  final MonthlyReportFilter filter;
  final ValueChanged<MonthlyReportFilter> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider(false)).valueOrNull ?? const [];
    var accountLabel = 'Alle Konten';
    for (final account in accounts) {
      if (account.uuid == filter.accountUuid) accountLabel = account.name;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Vorheriger Monat',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => onChanged(filter.shiftMonths(-1)),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => _pickMonth(context),
                  child: Text(formatMonthYearDe(filter.year, filter.month)),
                ),
              ),
              IconButton(
                tooltip: 'Nächster Monat',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => onChanged(filter.shiftMonths(1)),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                label: Text(accountLabel),
                onPressed: () async {
                  final pick = await pickAccount(
                    context,
                    selected: filter.accountUuid,
                  );
                  if (pick != null) onChanged(filter.withAccount(pick.accountUuid));
                },
              ),
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
                selected: {filter.direction},
                onSelectionChanged: (selection) =>
                    onChanged(filter.withDirection(selection.first)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: filter.monthStart,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Monat wählen',
    );
    if (picked != null) onChanged(filter.withMonth(picked));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final MonthlyReportFilter filter;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'Keine Transaktionen für ${formatMonthYearDe(filter.year, filter.month)}',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _UncategorizedTile extends StatelessWidget {
  const _UncategorizedTile({required this.cents});

  final int cents;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(Icons.help_outline, size: 16, color: muted),
      ),
      title: Text('Ohne Kategorie', style: TextStyle(color: muted)),
      subtitle: Text('nicht im Diagramm', style: TextStyle(color: muted)),
      trailing: Text(formatCentsEur(cents), style: TextStyle(color: muted)),
    );
  }
}

class _SliceTile extends StatelessWidget {
  const _SliceTile({
    required this.slice,
    required this.share,
    required this.onTap,
    required this.onLongPress,
  });

  final _Slice slice;
  final double share;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: CircleAvatar(
      radius: 16,
      backgroundColor: categoryColor(slice.colorHex),
      child: Icon(
        categoryIcon(slice.iconName),
        size: 16,
        color: Colors.white,
      ),
    ),
    title: Text(slice.name),
    subtitle: Text('${(share * 100).round()} %'),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(formatCentsEur(slice.cents)),
        if (onTap != null) const Icon(Icons.chevron_right),
      ],
    ),
    onTap: onTap,
    onLongPress: onLongPress,
  );
}

class _Slice {
  const _Slice({
    required this.name,
    required this.iconName,
    required this.colorHex,
    required this.cents,
    required this.categoryUuid,
    required this.drilldownUuid,
  });

  final String name;
  final String iconName;
  final String colorHex;
  final int cents;

  /// `null` on the `(direkt)` pseudo row — it stands for a slice of a category,
  /// not for a category of its own.
  final String? categoryUuid;

  /// `null` for a leaf category and for the `(direkt)` pseudo row — neither has
  /// a level below it.
  final String? drilldownUuid;
}
