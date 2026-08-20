# Search in the category picker

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Categories |
| **Domain** | Category |
| **Blocked By** | None (026 shipped the quick-create rows this has to coexist with) |
| **Status** | Ready |

## Description
The picker shows the whole tree with every node expanded, which stops working as the tree grows: finding one category
means scrolling past all the others. Wanted: a search field that narrows the sheet.

The matching rule is given with the request and is **not** a plain filter:

> Searching `Lebensmittel` shows every category whose name contains `Lebensmittel`, **and** every subcategory hanging
> below such a category — however deep.

So a hit pulls its whole subtree along. Searching a parent name is how you get at children whose own names say nothing
about their parent (`Bio`, `Wochenmarkt`), which is exactly when the flat filter of most pickers fails.

## Acceptance Criteria
- [ ] Search field in the picker sheet; empty input shows the full tree as today
- [ ] A category matches when its name contains the query, case-insensitively
- [ ] Every descendant of a matching category is shown too, at any depth, whether or not it matches itself
- [ ] Matching rows stay in their tree shape, with their indentation — a hit deep in the tree still reads as belonging
      where it belongs
- [ ] `Neue Kategorie` and the per-row `+` from ticket 026 keep working while a search is active
- [ ] The none-option keeps its first slot and its `noneLabel` wording
- [ ] The path to a hit is shown and stays selectable, so indentation keeps its meaning
- [ ] Matching is case-insensitive substring; umlauts are compared literally
- [ ] Archived categories never appear, filtered or not
- [ ] Clearing the field restores the full tree, and a quick-create closes the sheet as it does today
- [ ] `CategoryTreeScreen` is untouched
- [ ] Tests over a three-level tree: a hit, a descendant of a hit at depth three, an ancestor shown as path, no match, and
      quick-create while filtered
- [ ] `make check` green

## Resolved during refinement
- **Ancestors** → the path to a hit is shown and behaves like any other row: selectable, with its `+`. The sheet stays "the
  tree, filtered", so no new row state appears and nothing becomes half-interactive. Picking `Lebensmittel` after searching
  `Bio` is a sensible action. Accepted cost: the result contains rows that do not contain the query
- **Matching** → case-insensitive substring, otherwise literal. Umlauts stay umlauts, so `Bruehe` does not find `Brühe`.
  `normalizeForMatching` was rejected: it is built for machine comparison in dedupe and tagging, and changing it later would
  silently change search behaviour
- **After a quick-create** → unchanged from 026: the sheet closes and returns the new category as the pick, so the search ends
  with it. The awkward case — a new category that does not match the active filter — cannot arise. Rejected prefilling the
  query as the name: with substring search that puts half a word in the field
- **Archived categories** → stay excluded. The picker deliberately reads `includeArchived: false` and an archived category is
  not selectable, so surfacing it in search would be a trap
- **Where** → `pickCategory` only, not `CategoryTreeScreen`. The tree screen has the same growth problem but also
  drag-reorder, and reordering a filtered list is meaningless. That needs its own decision, hence its own ticket
- **Fixtures** → a three-level tree, built inline in the test. Two levels would only prove the descendant rule where it is
  still trivial

## Out of Scope (proposed, to confirm)
- Fuzzy or typo-tolerant matching; substring is what was asked for
- Reordering results by relevance — tree order is the point

## Affected Tests
- New: matching semantics (hit, descendant of a hit, no match) and that quick-create still works while filtered
- `test/features/category/presentation/category_picker_quick_create_test.dart` and
  `manual_entry_category_required_test.dart` must both stay green

## Fixtures Needed
No file. A three-level tree built inline in the test, deeper than the two-level trees the picker tests use today.

### Refinement Tokens (estimate)
- Input: ~12k tokens
- Output: ~2k tokens

### Implementation Tokens (estimate)
_Filled after Done._
