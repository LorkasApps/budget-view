import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../../../category/data/category.dart';
import '../../../category/domain/category_providers.dart';
import '../../../category/presentation/category_chip.dart';
import '../../../category/presentation/category_picker.dart';
import '../../../tagging/domain/tagging_suggest_service.dart';
import '../../../tagging/presentation/suggestion_sheet.dart';
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
  Map<int, List<CategorySuggestion>> suggestions = const {},
  int? expectedSumCents,
  List<String> unreadRows = const [],
  Future<String?> Function()? onDumpRecognition,
}) {
  return Navigator.of(context).push<List<LineItemCandidate>>(
    MaterialPageRoute(
      builder: (_) => ScanReviewScreen(
        transaction: transaction,
        candidates: candidates,
        suggestions: suggestions,
        expectedSumCents: expectedSumCents,
        unreadRows: unreadRows,
        onDumpRecognition: onDumpRecognition,
      ),
    ),
  );
}

class ScanReviewScreen extends ConsumerStatefulWidget {
  const ScanReviewScreen({
    super.key,
    required this.transaction,
    required this.candidates,
    this.suggestions = const {},
    this.expectedSumCents,
    this.unreadRows = const [],
    this.onDumpRecognition,
  });

  final Transaction transaction;
  final List<LineItemCandidate> candidates;

  /// Candidate index → article rules learned for that description, strongest
  /// first (ticket 056). Handed in like [candidates] rather than read from the
  /// flow provider, so this screen stays drivable without one.
  final Map<int, List<CategorySuggestion>> suggestions;

  /// Rows the parser read but could not use. Shown behind a collapsed line: the
  /// OCR plugin has no test-VM binding, so this screen is the only place raw
  /// recognised text can be inspected when a layout reads as an empty receipt
  /// (ticket 045).
  final List<String> unreadRows;

  /// Writes the recognised layout somewhere and returns the path. Null hides the
  /// entry, which is how release builds and every test see this screen: the flow
  /// only hands it in under `kDebugMode` (ticket 055).
  final Future<String?> Function()? onDumpRecognition;

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

  Future<void> _dumpRecognition() async {
    final path = await widget.onDumpRecognition?.call();
    // Also to the console, and before the mounted check so the path survives
    // even if the screen is gone: the snackbar holds it for ten seconds, and
    // copying a cache path off a device screen in that window is the fiddly bit.
    debugPrint('OCR dump: ${path ?? 'kein Ergebnis'}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(path ?? 'Kein OCR-Ergebnis vorhanden'),
        duration: const Duration(seconds: 10),
      ),
    );
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

  /// The article rules for a row. Read from the widget rather than copied into
  /// state: `_candidates` is the user's edit buffer, the suggestions never change.
  ///
  /// Keyed by the parser's index, so a row the user **added** or deleted shifts
  /// the mapping. Deliberate: a hand-added row has no suggestion to lose, and the
  /// marker only renders while `categorySuggested` is still true, which an added
  /// row never has.
  List<CategorySuggestion> _suggestionsFor(int index) =>
      widget.suggestions[index] ?? const [];

  /// Alternatives are overrides, not acceptances: picking the runner-up must let
  /// the learn hook raise its count, or it could never overtake the leader.
  Future<void> _chooseAlternative(int index) async {
    final picked = await pickSuggestion(
      context,
      _suggestionsFor(index),
      selectedCategoryUuid: _candidates[index].categoryUuid,
    );
    if (picked == null) return;
    setState(() {
      _candidates[index] = _candidates[index].withCategory(picked.categoryUuid);
    });
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
          // `withCategory` rather than `copyWith`: this is an explicit bulk
          // action, so it overrides a suggested row and stops being a guess.
          candidate.includeInSave && candidate.isSavable
              ? candidate.withCategory(pick.uuid)
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
          if (widget.onDumpRecognition != null)
            IconButton(
              tooltip: 'OCR-Layout sichern',
              icon: const Icon(Icons.bug_report_outlined),
              onPressed: _dumpRecognition,
            ),
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
              suggestions: _suggestionsFor(index),
              onTap: () => _edit(index),
              onShowAlternatives: () => _chooseAlternative(index),
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
          if (widget.unreadRows.isNotEmpty)
            _UnreadRows(rows: widget.unreadRows),
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
    required this.suggestions,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    required this.onShowAlternatives,
  });

  final LineItemCandidate candidate;

  /// The article rules found for this description, strongest first. Empty for a
  /// row nothing was learned for.
  final List<CategorySuggestion> suggestions;

  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onShowAlternatives;

  int get _hitCount {
    for (final suggestion in suggestions) {
      if (suggestion.categoryUuid == candidate.categoryUuid) {
        return suggestion.hitCount;
      }
    }
    return 0;
  }

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
            else ...[
              if (candidate.categoryUuid != null)
                CategoryChip(categoryUuid: candidate.categoryUuid),
              // Rendered whenever rules exist for this article, not only when one
              // of them filled the row: a tie fills nothing (ADR 0154), and the
              // marker is then the only way to reach the alternatives at all.
              // The count appears only when the row wears one of them.
              if (suggestions.isNotEmpty) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: suggestions.length > 1 ? onShowAlternatives : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        size: 14,
                        color: theme.colorScheme.tertiary,
                      ),
                      if (candidate.categorySuggested)
                        Text(
                          '$_hitCount×',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
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

/// The rows the parser could not turn into positions, raw and collapsed.
///
/// Collapsed because ticket 035 removed this list for being noise, and that is
/// still true on a receipt that read fine. Restored because its absence made a
/// layout the parser cannot read look like an empty receipt, with nothing to go
/// on (ticket 045). Nothing here can be selected or saved — it is text, not a
/// candidate.
class _UnreadRows extends StatelessWidget {
  const _UnreadRows({required this.rows});

  final List<String> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      leading: const Icon(Icons.help_outline),
      title: Text('${rows.length} nicht erkannte Zeilen'),
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(row, style: theme.textTheme.bodySmall),
            ),
          ),
      ],
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
