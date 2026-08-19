import 'package:flutter/material.dart';

import '../domain/tagging_suggest_service.dart';

/// How many alternatives the sheet offers. Beyond three the tail is noise: the
/// counts are already sorted, and a rule with two hits is not a real rival.
const maxSuggestionAlternatives = 3;

/// Lets the user pick one of the learned categories for a counterparty.
///
/// `null` means dismissed — the caller keeps whatever it had. Rows render the
/// name the suggestion carries rather than a `CategoryChip`, so the sheet needs
/// no category provider of its own.
Future<CategorySuggestion?> pickSuggestion(
  BuildContext context,
  List<CategorySuggestion> suggestions, {
  String? selectedCategoryUuid,
}) {
  return showModalBottomSheet<CategorySuggestion>(
    context: context,
    builder: (_) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Vorschläge',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final suggestion
              in suggestions.take(maxSuggestionAlternatives))
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text(suggestion.categoryName),
              trailing: Text('${suggestion.hitCount}×'),
              selected: suggestion.categoryUuid == selectedCategoryUuid,
              onTap: () => Navigator.pop(context, suggestion),
            ),
        ],
      ),
    ),
  );
}
