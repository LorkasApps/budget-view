# Fractal category inheritance

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Categories |
| **Domain** | Drilldown (was Category — the resolver and both UI surfaces live there) |
| **Blocked By** | 011, 015 |
| **Status** | Done |

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
- [x] Utility function `effectiveCategoryUuid(LineItem, Transaction) → String?` — **path changed** to `lib/features/drilldown/domain/category_resolver.dart`; the ticket's `features/category/` path would have pulled a new `Category → Drilldown` edge for a rule whose subject is the position. See decisions.md
- [x] Utility function `resolveTransactionCategories(Transaction, List<LineItem>) → Map<lineItemUuid, categoryUuid?>` for batch resolution
- [x] Both functions are pure + unit-tested; no repo access inside — plus `inheritsCategory(LineItem)`, which drives the badge
- [x] Line-item edit sheet: category picker offers "Erbt von der Buchung (<parent-category>)" as first option; picking it stores `null` — `pickCategory` gained a `noneLabel` parameter; the none-option already sat first. Falls back to "(ohne Kategorie)" while the booking itself is uncategorized
- [x] Line-item list row shows a badge: `inherited` (dimmed to 55 %, behind a `subdirectory_arrow_right` arrow) vs `override` (plain chip) — both render the **effective** category name. Sits in the row's subtitle, not the trailing slot, where a long name overflowed next to amount and drag handle
- [x] Analytics-side integration point documented: `.claude/docs/drilldown.md` names the resolver as mandatory for 020 + 022
- [x] Ticket 020 (monthly report) explicitly uses `effectiveCategoryUuid` for line-item aggregation — note added to 020's AC with the shipped path and the failure mode it prevents
- [x] Transaction-level category may still exist even when line-items override — it acts as the fallback / default for new line-items in the same transaction (a new position starts at `null`, i.e. inheriting)

## Semantics Edge Cases
- Transaction has line-items and each line-item overrides → transaction-level category is unused in analytics; still shown in UI as "default" hint.
- Transaction has line-items, some override, some inherit → mixed. Inherited ones roll up to transaction category.
- Transaction has no line-items → the transaction's own category is the authoritative one.
- Transaction has no category AND line-items also `null` → effective category = `null` (uncategorized).

## Affected Tests
- `test/features/drilldown/domain/category_resolver_test.dart` — all edge cases from above (**moved** with the resolver, out of `category/`)
- `test/features/drilldown/presentation/line_item_category_ui_test.dart` — inherit vs override badge, picker default option
- `test/features/drilldown/presentation/line_items_section_test.dart` + `line_item_edit_sheet_test.dart` — updated for the new `transaction:` / `parent:` parameters
- ~~Note added to `test/features/analytics/` future test file~~ — **dropped**: `test/features/analytics/` does not exist yet, and a Dart file without a `main()` fails the suite rather than documenting anything. The note went into ticket 020's AC instead

Suite after the ticket: 203 passed, 0 failed, 2 skipped (was 190).

Found while testing: the inherit label was built from a `ref.read` of the category stream during build, so it froze at the loading state and labelled every booking "ohne Kategorie". Now watched in `build`, read only in the tap handler.

Not verified: the badge and the renamed picker option were never driven in an emulator (Flutter does not run in the agent sandbox).

## Fixtures Needed
No — inline builders.

## Refinement Tokens (estimate)
- Input: ~7k tokens
- Output: ~2k tokens

### Implementation Tokens (estimate)
- Input: ~135k tokens (~111k of it the delegated test pass on Sonnet)
- Output: ~13k tokens
