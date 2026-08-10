# Fractal category inheritance

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Categories |
| **Domain** | Category |
| **Blocked By** | 011, 015 |
| **Status** | Ready |

## Description
Line-items may carry their own `categoryUuid`, overriding the parent transaction's category. When a line-item's `categoryUuid` is `null`, its **effective category** is inherited from the parent transaction. All analytics queries (tickets 020+) must resolve the effective category before aggregating. UI clearly distinguishes inherited vs overridden line-item categories.

The `categoryUuid` field on `LineItem` itself is defined in ticket 015. This ticket adds the **resolution logic, UI indicators, and integration points**.

## Rule

```
effectiveCategory(lineItem) =
  lineItem.categoryUuid ?? lineItem.transaction.categoryUuid

effectiveCategoryUuidFor(transaction) =
  if transaction has line-items:
     use per-line-item effective category (fractal rollup)
  else:
     transaction.categoryUuid
```

## Acceptance Criteria
- [ ] Utility function `effectiveCategoryUuid(LineItem, Transaction) → String?` in `lib/features/category/domain/category_resolver.dart`
- [ ] Utility function `resolveTransactionCategories(Transaction, List<LineItem>) → Map<lineItemUuid, categoryUuid?>` for batch resolution
- [ ] Both functions are pure + unit-tested; no repo access inside
- [ ] Line-item edit sheet: category picker offers "Inherit from transaction (<parent-category>)" as first option; picking it stores `null`
- [ ] Line-item list row shows a badge: `inherited` (subtle, small) vs `override` (accent color) — badge text refers to the effective category name
- [ ] Analytics-side integration point documented: tickets 020 + 022 read line-item's effective category via the utility above
- [ ] Ticket 020 (monthly report) explicitly uses `effectiveCategoryUuid` for line-item aggregation (this ticket adds a note to 020; actual wiring is validated when 020 lands)
- [ ] Transaction-level category may still exist even when line-items override — it acts as the fallback / default for new line-items in the same transaction

## Semantics Edge Cases
- Transaction has line-items and each line-item overrides → transaction-level category is unused in analytics; still shown in UI as "default" hint.
- Transaction has line-items, some override, some inherit → mixed. Inherited ones roll up to transaction category.
- Transaction has no line-items → the transaction's own category is the authoritative one.
- Transaction has no category AND line-items also `null` → effective category = `null` (uncategorized).

## Affected Tests
- `test/features/category/domain/category_resolver_test.dart` — all edge cases from above
- `test/features/drilldown/presentation/line_item_category_ui_test.dart` — inherit vs override badge, picker default option
- Note added to `test/features/analytics/` future test file describing expected behavior for 020

## Fixtures Needed
No — inline builders.

## Refinement Tokens (estimate)
- Input: ~7k tokens
- Output: ~2k tokens

## Token Usage
_Filled after Done._
