# Search in the category picker

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Categories |
| **Domain** | Category |
| **Blocked By** | None (026 shipped the quick-create rows this has to coexist with) |
| **Status** | Draft |

## Description
The picker shows the whole tree with every node expanded, which stops working as the tree grows: finding one category
means scrolling past all the others. Wanted: a search field that narrows the sheet.

The matching rule is given with the request and is **not** a plain filter:

> Searching `Lebensmittel` shows every category whose name contains `Lebensmittel`, **and** every subcategory hanging
> below such a category — however deep.

So a hit pulls its whole subtree along. Searching a parent name is how you get at children whose own names say nothing
about their parent (`Bio`, `Wochenmarkt`), which is exactly when the flat filter of most pickers fails.

## Acceptance Criteria (from the request; the questions below still open some)
- [ ] Search field in the picker sheet; empty input shows the full tree as today
- [ ] A category matches when its name contains the query, case-insensitively
- [ ] Every descendant of a matching category is shown too, at any depth, whether or not it matches itself
- [ ] Matching rows stay in their tree shape, with their indentation — a hit deep in the tree still reads as belonging
      where it belongs
- [ ] `Neue Kategorie` and the per-row `+` from ticket 026 keep working while a search is active
- [ ] The none-option keeps its first slot and its `noneLabel` wording

## Open questions for refinement
- **Are ancestors of a hit shown?** If `Bio` matches and its parent `Lebensmittel` does not, is `Bio` rendered as a root,
  or is `Lebensmittel` kept as unselectable context so the indentation still means something? Without ancestors the tree
  shape of the AC above cannot hold; with them, a shown row may not be selectable, which is new behaviour for this sheet
- **What does the `+` mean on a filtered row?** It creates a child of that row — harmless, but the new child may
  immediately vanish from the filtered view because its name does not match. Clear the search after a create?
- **Does `Neue Kategorie` prefill the query as the name?** Tempting (type, find nothing, create), and the request did not
  ask for it
- Is the query normalized (`normalizeForMatching`, which the tagging and dedupe paths share) or matched raw? Umlauts and
  case make this a real choice: `Lebensmittel` versus `lebensmittel` versus `Lebensmittel-Discounter`
- Does the search reach archived categories? The picker deliberately reads `includeArchived: false` today
- Where does it belong — inside `pickCategory` only, or also in `CategoryTreeScreen`, which has the same growth problem?

## Out of Scope (proposed, to confirm)
- Fuzzy or typo-tolerant matching; substring is what was asked for
- Reordering results by relevance — tree order is the point

## Affected Tests
- New: matching semantics (hit, descendant of a hit, no match) and that quick-create still works while filtered
- `test/features/category/presentation/category_picker_quick_create_test.dart` and
  `manual_entry_category_required_test.dart` must both stay green

## Fixtures Needed
Ask during refinement — a deeper tree than the two-root fixture the picker tests build inline today.

## Token Usage
_Filled after Done._
