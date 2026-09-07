# Category (Category domain)

User-defined free category tree (parent-child, arbitrary depth). Feature-first under `lib/features/category/`.

## Entity — `Category` (`data/category.dart`)
Implements `SyncableEntity` (`entityType = 'category'`).

| Field | Type | Notes |
|-------|------|-------|
| `id` | Id | Isar auto-inc, internal |
| `uuid` | String | UUID v4, unique index, business key |
| `name` | String | Non-empty; unique (case-insensitive) within same `parentUuid` |
| `parentUuid` | String? | **Nullable; null = root** (modelled as null, not empty string, for consistency with `Transaction.categoryUuid`) |
| `sortOrder` | int | Manual sibling order; default 1000 (gaps for single inserts) |
| `iconName` | String | Key into `categoryIcons` (e.g. `restaurant`, `directions_car`); default `label`; keys may be added but never renamed. Unknown key falls back to `label` |
| `colorHex` | String | 7-char hex incl. `#`; default `#607D8B`. The UI offers the palette, but any 6-digit hex parses; unparseable values fall back |
| `archived` | bool | Soft-delete marker; default `false` |
| `createdAt` / `updatedAt` | DateTime | Maintained by repo |

Direction (income vs expense) derived from transaction amount sign, never from category placement.

## Repository — `CategoryRepository` (`domain/category_repository.dart`)
| Method | Sync op |
|--------|---------|
| `save(category)` | create (new uuid) / update |
| `delete(uuid)` | delete (sets `archived=true`); throws `CategoryDeleteBlocked` if children or transactions exist |
| `restore(uuid)` | update (sets `archived=false`) |
| `reorderSiblings(ordered)` | update (only changed rows written) |
| `findByUuid(uuid)` | — |
| `findAll({includeArchived})` | — (sorted `sortOrder` then name) |
| `findChildren(String? parentUuid)` | — (sorted `sortOrder` then name); null yields roots, uses `parentUuidIsNull()` |
| `findRoots()` | delegates to `findChildren(null)` |

Follows docs/sync.md contract: `ensureUuid()` → Isar write → `syncAdapter.enqueue`.

Takes `TransactionRepository` as its third constructor argument, used only by `delete` to call `countByCategory` (see dependencies.md — deliberate narrow Category → Transaction edge).

## Exceptions — first domain exceptions in codebase

**`CategoryInvalid`**: thrown by `save()` on empty/too-long name, duplicate sibling name (case-insensitive), missing parent, category as own parent, or move creating a cycle. Field: `message` (German, user-facing).

**`CategoryDeleteBlocked`**: thrown by `delete()` when category has children or transactions; unblocks when moved first. Fields: `childCount`, `transactionCount` (counts non-deleted transactions referencing the category via `TransactionRepository.countByCategory()`), `.message` (German, user-facing: "Kategorie hat X Unterkategorien und Y Buchungen — bitte zuerst verschieben.").

## Tree Helpers (`domain/category_tree.dart`)
Pure tree-building functions:

- **`CategoryNode`**: immutable struct of `{category, children: List<CategoryNode>, depth}`. `hasChildren` is a getter.
- **`buildCategoryTree(categories)`**: groups flat list into roots + children. Siblings order by `sortOrder` then case-insensitive `name`. A category whose parent is null or absent is promoted to a root (orphaned archived parents never hide their children).
- **`flattenVisible(roots, expanded)`**: depth-first traversal for on-screen list; a node's children included only if its uuid is in the `expanded` set.
- **`filterCategoryTree(roots, query)`**: prunes tree for search; a name hit keeps its whole subtree, non-matching ancestors kept as path to matching descendants, case-insensitive substring (umlauts literal), empty query returns roots unchanged, node depth preserved.
- **`subtreeUuids(categories, rootUuid)`**: `rootUuid` plus every uuid below it, by fixpoint walk over `parentUuid`. Empty `rootUuid` yields nothing. Backs the booking-list category filter (053), where picking a parent must show its children's bookings.
- **`ineligibleParents(categories, category)`**: returns set of uuids that cannot be the category's parent (itself + all descendants; guards cycle prevention). Delegates to `subtreeUuids` — the same walk, which only ever carried a name about parent eligibility.

## Providers (`domain/category_providers.dart`)
- `categoryRepositoryProvider` → `CategoryRepository(isar, syncAdapter, transactionRepository)`
- `categoriesProvider` (`StreamProvider.family<List<Category>, bool>`) — reactive flat list; param = includeArchived. Emits initial snapshot then re-queries on `isar.categorys.watchLazy()`.

## Validation (`domain/category_validation.dart`)
`CategoryValidation.name(String?)` — rejects empty/too-long (>60 chars) names. Sibling uniqueness enforced in repository only.

## UI (`presentation/`)
**`CategoryTreeScreen`**: expandable tree view, drag-to-reorder within siblings, tap → edit, long-press → archive (refused if children exist—UI checks before asking). Show archived toggle in app bar. Archived rows show restore button instead of drag handle. Reorder across levels refused with snackbar.

Search (ticket 054), through the same `filterCategoryTree` as the picker:

| While a query is active | Why |
|-------------------------|-----|
| Every node counts as expanded | `filterCategoryTree` keeps the path down to a hit, and this screen starts collapsed — a collapsed path is a path nobody sees. `_expanded` is not touched, so clearing the search restores the previous collapse state |
| Plain `ListView`, not `ReorderableListView` | Handles *and* the widget itself go: `ReorderableListView` also offers reorder via semantics actions, so hiding the handle alone would leave sorting reachable on a filtered list |
| Hint `Sortieren erst ohne Suche` | Says why the handles left |
| Expand chevrons hidden | Everything is expanded; a toggle that does nothing visible is worse than none |
| `N Unterkategorien` counted off the **unfiltered** list | A path node's children are pruned by the filter, and a number shrinking with a query reads as if children were archived or lost. `_delete` uses the same count, so its refusal states the real number |
| Archived rows follow the toggle only | Search narrows what the screen shows; the toggle decides what the screen is about. A query must not override an explicit choice |
| `Kein Treffer.` on no match | Same string as the picker |

Testing note: `find.text('<name>')` matches twice on this screen once a query is typed — the search field holds that text too. Use `find.widgetWithText(ListTile, name)`.

Non-obvious details:
- `buildDefaultDragHandles: false` with explicit `ReorderableDragStartListener` handle (default would hijack long-press needed for archive).
- Visible children count shown as subtitle.
- Deletion pre-check: refuses immediately if children known in current list rather than asking then refusing (repository still guards, including hidden archived children).

**`CategoryFormScreen`**: full screen (not bottom sheet), create/edit fields: name (validated), parent picker (blocked set excludes category + descendants), icon grid (24 icons from `categoryIcons` map), color grid (12 from palette). Reads all non-archived categories to build parent picker and determine ineligible set. FAB to create.

**`category_picker.dart`**: `pickCategory(context, {selected, allowNone, noneLabel})` returns `Future<CategoryPick?>`. `noneLabel` renames the first option where "none" carries a specific meaning — line-items pass "Erbt von der Buchung (…)". Bottom sheet: title, none-option (if `allowNone`), divider, "Neue Kategorie" row (`Icons.add`, creates at root), divider, then tree rows expanded. Any node selectable (leaf or non-leaf). Returning null means dismissed; returning `CategoryPick(null)` means deliberately cleared—this distinction is load-bearing. 
  - **Search**: dense `TextField` below title, `prefixIcon` `Icons.search`, `hintText` `Suchen`, `OutlineInputBorder`, clear `IconButton` (tooltip `Suche leeren`) shows when query non-empty; filters tree via `filterCategoryTree`, shows `Kein Treffer.` when no match; none-option and "Neue Kategorie" row survive active filter. `CategoryTreeScreen` has none: reordering a filtered list is meaningless.
  - **Quick-create** (`_QuickCreateDialog`, private): each tree row carries a trailing `IconButton` (`Icons.add`, tooltip `Unterkategorie in <name>`) that opens an `AlertDialog` (title `Neue Kategorie` or `Neue Unterkategorie in <parent>`, single `Name` field, buttons `Abbrechen`/`Anlegen`). Icon, colour, sortOrder use entity defaults (`label`, `#607D8B`, 1000). Validation: `CategoryValidation.name` first, then `CategoryRepository.save` — `CategoryInvalid` from duplicate sibling becomes `errorText`, dialog stays open. On success, returns `CategoryPick(newUuid)` to the caller without a second tap. Root "Neue Kategorie" row creates with `parentUuid = null`; per-row `+` button creates a child whose `parentUuid` is that row's `uuid`. Row tap still selects (separate hit area: row tap = select, `+` icon = create child).

**`category_chip.dart`**: `CategoryChip({categoryUuid, onTap})` compact label for transaction rows and import previews. Reads the archived list so a transaction pointing at an archived category still renders. Shows `—` when uncategorized, `?` if uuid points nowhere.

**`category_style.dart`**: 
- `categoryIcons` map (24 keys: `label`, `shopping_cart`, `restaurant`, `local_cafe`, `home`, `bolt`, `water_drop`, `wifi`, `smartphone`, `directions_car`, `local_gas_station`, `train`, `medical_services`, `fitness_center`, `school`, `child_care`, `pets`, `movie`, `sports_esports`, `card_giftcard`, `savings`, `payments`, `receipt_long`, `shield`). Keys are persisted; never rename.
- `categoryPalette` list (12 hex colors: red, pink, purple, indigo, blue, teal, green, amber, orange, brown, grey).
- Helpers: `categoryIcon(name)` (fallback to `label`), `categoryColor(hex)` (fallback to `#607D8B`).

## Navigation
From `AccountListScreen` app bar: category icon button → `CategoryTreeScreen`.

## Not in scope here
- Fractal line-item category override — the resolver lives in `drilldown.md` (ticket 012)
- Import/export of category presets
