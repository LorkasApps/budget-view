import 'package:budget_view/features/drilldown/data/line_item.dart';
import 'package:budget_view/features/drilldown/domain/category_resolver.dart';
import 'package:budget_view/features/transaction/data/transaction.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure resolver tests, no Isar, no widgets: the fractal category rule is a
/// plain function of a [LineItem] and its parent [Transaction].
LineItem _item({required String uuid, String? categoryUuid}) {
  final now = DateTime(2026, 8, 1);
  return LineItem()
    ..uuid = uuid
    ..transactionUuid = 'tx-1'
    ..description = 'Position'
    ..amountCents = -100
    ..categoryUuid = categoryUuid
    ..createdAt = now
    ..updatedAt = now;
}

Transaction _transaction({String? categoryUuid}) {
  final now = DateTime(2026, 8, 1);
  return Transaction()
    ..uuid = 'tx-1'
    ..accountUuid = 'acc-1'
    ..categoryUuid = categoryUuid
    ..amountCents = -500
    ..bookingDate = now
    ..description = 'Supermarkt'
    ..createdAt = now
    ..updatedAt = now;
}

void main() {
  group('effectiveCategoryUuid', () {
    test("the position's own category wins over the parent's", () {
      final item = _item(uuid: 'a', categoryUuid: 'cat-item');
      final parent = _transaction(categoryUuid: 'cat-parent');

      expect(effectiveCategoryUuid(item, parent), 'cat-item');
    });

    test("a null position category inherits the parent's", () {
      final item = _item(uuid: 'a');
      final parent = _transaction(categoryUuid: 'cat-parent');

      expect(effectiveCategoryUuid(item, parent), 'cat-parent');
    });

    test('a null position category and a null parent category resolve to '
        'uncategorized', () {
      final item = _item(uuid: 'a');
      final parent = _transaction();

      expect(effectiveCategoryUuid(item, parent), isNull);
    });
  });

  group('resolveTransactionCategories', () {
    test('keys the map by line-item uuid', () {
      final parent = _transaction(categoryUuid: 'cat-parent');
      final items = [
        _item(uuid: 'a', categoryUuid: 'cat-item'),
        _item(uuid: 'b'),
      ];

      final result = resolveTransactionCategories(parent, items);

      expect(result.keys, {'a', 'b'});
    });

    test('resolves each row independently: mixed override and inherit', () {
      final parent = _transaction(categoryUuid: 'cat-parent');
      final items = [
        _item(uuid: 'a', categoryUuid: 'cat-item'),
        _item(uuid: 'b'),
        _item(uuid: 'c', categoryUuid: 'cat-other'),
      ];

      final result = resolveTransactionCategories(parent, items);

      expect(result, {
        'a': 'cat-item',
        'b': 'cat-parent',
        'c': 'cat-other',
      });
    });

    test('an empty item list yields an empty map', () {
      final parent = _transaction(categoryUuid: 'cat-parent');

      expect(resolveTransactionCategories(parent, const []), isEmpty);
    });

    test('a null parent category leaves inheriting rows uncategorized', () {
      final parent = _transaction();
      final items = [_item(uuid: 'a'), _item(uuid: 'b', categoryUuid: 'x')];

      final result = resolveTransactionCategories(parent, items);

      expect(result, {'a': null, 'b': 'x'});
    });
  });

  group('inheritsCategory', () {
    test('is true when the position carries no category of its own', () {
      expect(inheritsCategory(_item(uuid: 'a')), isTrue);
    });

    test('is false when the position overrides the category', () {
      final item = _item(uuid: 'a', categoryUuid: 'cat-item');

      expect(inheritsCategory(item), isFalse);
    });
  });
}
