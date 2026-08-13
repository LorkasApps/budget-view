import '../../transaction/data/transaction.dart';
import '../data/line_item.dart';

/// Fractal category rule: a position's own category wins, `null` inherits the
/// parent booking's. Both may be null — then the position is uncategorized.
///
/// Pure by contract: analytics (tickets 020, 022) must resolve through here
/// before aggregating, so the rule cannot drift between call sites.
String? effectiveCategoryUuid(LineItem item, Transaction parent) =>
    item.categoryUuid ?? parent.categoryUuid;

/// Batch form of [effectiveCategoryUuid], keyed by [LineItem.uuid].
///
/// Takes [items] as given — filtering soft-deleted rows is the caller's job,
/// and `LineItemRepository.findByTransaction` already does it.
Map<String, String?> resolveTransactionCategories(
  Transaction parent,
  List<LineItem> items,
) {
  return {
    for (final item in items) item.uuid: effectiveCategoryUuid(item, parent),
  };
}

/// Whether the position falls back to its parent instead of carrying its own
/// category. Drives the inherited/override badge.
bool inheritsCategory(LineItem item) => item.categoryUuid == null;
