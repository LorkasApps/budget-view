import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../../../category/data/category.dart';
import '../../../category/domain/category_providers.dart';
import '../../../category/presentation/category_chip.dart';
import '../../../category/presentation/category_picker.dart';
import '../../../transaction/data/transaction.dart';
import '../../domain/line_item_validation.dart';
import '../domain/receipt_line_item_parser.dart';
import 'candidate_edit_sheet.dart';

/// Shows what OCR made of the receipt and lets the user fix it.
///
/// Returns the reviewed candidates, or null when the user backs out — which the
/// scan flow treats as a cancel, so nothing is persisted.
Future<List<LineItemCandidate>?> pushScanReview(
  BuildContext context, {
  required Transaction transaction,
  required List<LineItemCandidate> candidates,
  int? expectedSumCents,
}) {
  return Navigator.of(context).push<List<LineItemCandidate>>(
    MaterialPageRoute(
      builder: (_) => ScanReviewScreen(
        transaction: transaction,
        candidates: candidates,
        expectedSumCents: expectedSumCents,
      ),
    ),
  );
}

class ScanReviewScreen extends ConsumerStatefulWidget {
  const ScanReviewScreen({
    super.key,
    required this.transaction,
    required this.candidates,
    this.expectedSumCents,
  });

  final Transaction transaction;
  final List<LineItemCandidate> candidates;

  /// What the kept positions have to add up to — the receipt's printed total plus
  /// any credit rows it already accounted for. Null when the document printed no
  /// total. The one check that does not depend on how the rows were grouped.
  final int? expectedSumCents;

  @override
  ConsumerState<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends ConsumerState<ScanReviewScreen> {
  late List<LineItemCandidate> _candidates =
      List<LineItemCandidate>.of(widget.candidates);

  int get _sign => widget.transaction.amountCents.isNegative ? -1 : 1;

  Iterable<LineItemCandidate> get _included =>
      _candidates.where((c) => c.includeInSave && c.isSavable);

  int get _includedSum =>
      _included.fold<int>(0, (sum, c) => sum + (c.amountCents ?? 0));

  /// Set as soon as the user changes the selection: a difference to the printed
  /// total is then intended, and warning about it would be noise.
  bool _selectionTouched = false;

  int? get _totalMismatchCents {
    final expected = widget.expectedSumCents;
    if (expected == null || _selectionTouched) return null;
    final difference = _includedSum - expected;
    return difference == 0 ? null : difference;
  }

  Future<void> _edit(int index) async {
    final edited = await showCandidateSheet(
      context,
      candidate: _candidates[index],
      parent: widget.transaction,
    );
    if (edited == null) return;
    setState(() => _candidates[index] = edited);
  }

  Future<void> _add() async {
    final created = await showCandidateSheet(
      context,
      candidate: LineItemCandidate(),
      parent: widget.transaction,
    );
    if (created == null) return;
    setState(() => _candidates.add(created));
  }

  /// Applies one category to every row the user kept. Rows excluded from the
  /// save are left alone — they are not part of the booking.
  Future<void> _categorizeAll() async {
    final categories =
        ref.read(categoriesProvider(true)).valueOrNull ?? const <Category>[];
    final pick = await pickCategory(
      context,
      allowNone: true,
      noneLabel: _inheritLabel(categories),
    );
    if (pick == null) return;
    setState(() {
      _candidates = [
        for (final candidate in _candidates)
          candidate.includeInSave && candidate.isSavable
              ? candidate.copyWith(categoryUuid: pick.uuid)
              : candidate,
      ];
    });
  }

  String _inheritLabel(List<Category> categories) {
    final uuid = widget.transaction.categoryUuid;
    if (uuid == null) return 'Erbt von der Buchung (ohne Kategorie)';
    for (final category in categories) {
      if (category.uuid == uuid) {
        return 'Erbt von der Buchung (${category.name})';
      }
    }
    return 'Erbt von der Buchung';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Erkannte Positionen'),
        actions: [
          IconButton(
            tooltip: 'Alle kategorisieren',
            icon: const Icon(Icons.local_offer_outlined),
            onPressed: _candidates.isEmpty ? null : _categorizeAll,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          if (_totalMismatchCents != null)
            _TotalMismatchBanner(
              positionsCents: _sign * _includedSum,
              expectedCents: _sign * widget.expectedSumCents!,
            ),
          if (_candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Es wurde keine Position erkannt. Du kannst Zeilen manuell '
                'hinzufügen oder den Scan verwerfen.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          for (var index = 0; index < _candidates.length; index++)
            _CandidateRow(
              key: ValueKey(index),
              candidate: _candidates[index],
              onTap: () => _edit(index),
              onToggle: (value) => setState(() {
                _selectionTouched = true;
                _candidates[index] =
                    _candidates[index].copyWith(includeInSave: value);
              }),
              onDelete: () => setState(() => _candidates.removeAt(index)),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Zeile hinzufügen'),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Σ ${formatCentsEur(_sign * _includedSum)} von '
                '${formatCentsEur(widget.transaction.amountCents)}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Verwerfen'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, _candidates),
                      child: Text('${_included.length} übernehmen'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    super.key,
    required this.candidate,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final LineItemCandidate candidate;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  String? get _quantityLine {
    final quantity = candidate.quantity;
    final unitPrice = candidate.unitPriceCents;
    if (quantity == null && unitPrice == null) return null;
    if (quantity == null) return '${formatCentsEur(unitPrice!)} / Einheit';
    if (unitPrice == null) return LineItemValidation.quantityLabel(quantity);
    return '${LineItemValidation.quantityLabel(quantity)} × '
        '${formatCentsEur(unitPrice)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ambiguous = candidate.parseState == LineItemParseState.ambiguous;
    final quantityLine = _quantityLine;

    return Container(
      color: ambiguous ? theme.colorScheme.tertiaryContainer : null,
      child: ListTile(
        leading: Checkbox(
          // A row the repository would reject cannot be included until the
          // user completes it.
          onChanged: candidate.isSavable
              ? (value) => onToggle(value ?? false)
              : null,
          value: candidate.includeInSave && candidate.isSavable,
        ),
        title: Text(
          candidate.description.isEmpty
              ? 'Ohne Beschreibung'
              : candidate.description,
        ),
        subtitle: Row(
          children: [
            if (ambiguous)
              Text('Beschreibung fehlt', style: theme.textTheme.bodySmall)
            else if (candidate.categoryUuid != null)
              CategoryChip(categoryUuid: candidate.categoryUuid),
            if (quantityLine != null)
              Flexible(
                child: Text(
                  ' · $quantityLine',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (candidate.amountCents != null)
              Text(formatCentsEur(candidate.amountCents!)),
            IconButton(
              tooltip: 'Zeile entfernen',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Says that the receipt's total and the kept positions disagree, with both
/// figures — a shifted or missed row is invisible otherwise.
class _TotalMismatchBanner extends StatelessWidget {
  const _TotalMismatchBanner({
    required this.positionsCents,
    required this.expectedCents,
  });

  final int positionsCents;
  final int expectedCents;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.all(16),
      child: Text(
        'Positionen ergeben ${formatCentsEur(positionsCents)}, der Beleg erwartet '
        '${formatCentsEur(expectedCents)}. Bitte die Zeilen prüfen.',
        style: TextStyle(color: scheme.onErrorContainer),
      ),
    );
  }
}
