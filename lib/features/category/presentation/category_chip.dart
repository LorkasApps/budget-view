import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/category_providers.dart';
import 'category_style.dart';

/// Compact category label for transaction rows and import previews.
///
/// Reads the archived list too: a transaction may point at a category the user
/// has since archived, and showing nothing there would look like a bug.
class CategoryChip extends ConsumerWidget {
  const CategoryChip({super.key, required this.categoryUuid, this.onTap});

  final String? categoryUuid;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final uuid = categoryUuid;

    if (uuid == null) {
      return _Shell(
        onTap: onTap,
        border: theme.dividerColor,
        child: Text('—', style: theme.textTheme.labelMedium),
      );
    }

    final categories = ref.watch(categoriesProvider(true)).valueOrNull;
    final category =
        categories?.where((entry) => entry.uuid == uuid).firstOrNull;
    if (category == null) {
      return _Shell(
        onTap: onTap,
        border: theme.dividerColor,
        child: Text('?', style: theme.textTheme.labelMedium),
      );
    }

    final color = categoryColor(category.colorHex);
    return _Shell(
      onTap: onTap,
      border: color,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(categoryIcon(category.iconName), size: 14, color: color),
          const SizedBox(width: 4),
          Text(category.name, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child, required this.border, this.onTap});

  final Widget child;
  final Color border;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: child,
      ),
    );
  }
}
