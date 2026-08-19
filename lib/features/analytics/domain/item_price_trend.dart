/// One purchase of an item: what a unit cost on the booking's day.
class PricePoint {
  const PricePoint({required this.date, required this.unitPriceCents});

  final DateTime date;

  /// Magnitude — the direction of the parent booking is not interesting here.
  final int unitPriceCents;
}

/// One distinct normalized description across all bookings.
///
/// Sorts of the same product stay separate groups on purpose: `h-milch 1,5 %`
/// and `h-milch 3,5 %` are different goods with different prices, and no
/// heuristic can tell that apart from an OCR typo.
class ItemGroup {
  const ItemGroup({
    required this.normalizedKey,
    required this.label,
    required this.purchaseCount,
    required this.latestUnitPriceCents,
    required this.latestDate,
  });

  final String normalizedKey;

  /// Spelling of the most recent purchase — the group has as many spellings as
  /// it has whitespace and casing variants, and the newest is the best guess at
  /// how the user writes it today.
  final String label;
  final int purchaseCount;
  final int latestUnitPriceCents;
  final DateTime latestDate;
}

/// Every purchase of one item group, oldest first.
class ItemPriceSeries {
  const ItemPriceSeries({
    required this.normalizedKey,
    required this.label,
    required this.points,
  });

  ItemPriceSeries.emptyFor(String normalizedKey)
    : this(
        normalizedKey: normalizedKey,
        label: normalizedKey,
        points: const [],
      );

  final String normalizedKey;
  final String label;
  final List<PricePoint> points;

  bool get isEmpty => points.isEmpty;
  int get count => points.length;

  int? get minUnitPriceCents => points.isEmpty
      ? null
      : points.map((point) => point.unitPriceCents).reduce(_min);

  int? get maxUnitPriceCents => points.isEmpty
      ? null
      : points.map((point) => point.unitPriceCents).reduce(_max);

  static int _min(int a, int b) => a < b ? a : b;
  static int _max(int a, int b) => a > b ? a : b;
}
