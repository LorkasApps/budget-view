import 'package:flutter/material.dart';

import '../../../core/format/date_format.dart';
import '../../../core/money/money.dart';
import '../domain/result_series.dart';

/// Column weights shared by the summary line and the month rows below it — the
/// two only read as a table while they use the same ones.
const _labelFlex = 3;
const _figureFlex = 4;

/// Red below zero, green above, and the default colour at zero. The same pair
/// the booking list uses for a signed amount.
Color? netResultColor(BuildContext context, int cents) {
  if (cents < 0) return Theme.of(context).colorScheme.error;
  if (cents > 0) return Colors.green.shade700;
  return null;
}

/// `Einnahmen · Ausgaben · Ergebnis` for one span, in that order.
///
/// The result is shown **with its sign** — the deliberate exception to this
/// screen's magnitudes-only rule, because a result without a sign says nothing
/// (see decisions.md). The figures always cover both directions, so the
/// report's direction filter must not reach them.
class ResultSummaryLine extends StatelessWidget {
  const ResultSummaryLine({super.key, required this.series, this.leadingLabel});

  final ResultSeries series;

  /// Rendered as a first column when set, which is what lets this line double
  /// as the header row of [YearResultView]'s table.
  final String? leadingLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (leadingLabel != null)
            Expanded(
              flex: _labelFlex,
              child: Text(
                leadingLabel!,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          _Figure(label: 'Einnahmen', cents: series.incomeCents),
          _Figure(label: 'Ausgaben', cents: series.expenseCents),
          _Figure(label: 'Ergebnis', cents: series.netCents, isResult: true),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.cents,
    this.isResult = false,
  });

  final String label;
  final int cents;
  final bool isResult;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      flex: _figureFlex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            isResult ? formatCentsEurSigned(cents) : formatCentsEur(cents),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isResult ? FontWeight.w700 : null,
              color: isResult ? netResultColor(context, cents) : null,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// The twelve months of one year: the year's figures as the header row, then
/// one row per month under them. In year mode this breakdown **is** the table —
/// a category table across twelve months answers a different question.
class YearResultView extends StatelessWidget {
  const YearResultView({
    super.key,
    required this.year,
    required this.series,
    required this.onMonthTap,
  });

  final int year;
  final ResultSeries series;

  /// A row leads back into month mode for that month — seeing an outlier in the
  /// year is the moment its categories are wanted.
  final ValueChanged<MonthResult> onMonthTap;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(bottom: 24),
    children: [
      ResultSummaryLine(series: series, leadingLabel: '$year'),
      const Divider(height: 1),
      for (final point in series.points)
        _MonthRow(point: point, onTap: () => onMonthTap(point)),
    ],
  );
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({required this.point, required this.onTap});

  final MonthResult point;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: _labelFlex,
              child: Text(
                monthNamesDe[point.month - 1],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _Amount(text: formatCentsEur(point.incomeCents), style: muted),
            _Amount(text: formatCentsEur(point.expenseCents), style: muted),
            _Amount(
              text: formatCentsEurSigned(point.netCents),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: netResultColor(context, point.netCents),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.text, required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Expanded(
    flex: _figureFlex,
    child: Text(
      text,
      style: style,
      textAlign: TextAlign.end,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}
