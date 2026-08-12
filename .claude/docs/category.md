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
- **`ineligibleParents(categories, category)`**: returns set of uuids that cannot be the category's parent (itself + all descendants; guards cycle prevention).

## Providers (`domain/category_providers.dart`)
- `categoryRepositoryProvider` → `CategoryRepository(isar, syncAdapter, transactionRepository)`
- `categoriesProvider` (`StreamProvider.family<List<Category>, bool>`) — reactive flat list; param = includeArchived. Emits initial snapshot then re-queries on `isar.categorys.watchLazy()`.

## Validation (`domain/category_validation.dart`)
`CategoryValidation.name(String?)` — rejects empty/too-long (>60 chars) names. Sibling uniqueness enforced in repository only.

## UI (`presentation/`)
**`CategoryTreeScreen`**: expandable tree view, drag-to-reorder within siblings, tap → edit, long-press → archive (refused if children exist—UI checks before asking). Show archived toggle in app bar. Archived rows show restore button instead of drag handle. Reorder across levels refused with snackbar.

Non-obvious details:
- `buildDefaultDragHandles: false` with explicit `ReorderableDragStartListener` handle (default would hijack long-press needed for archive).
- Visible children count shown as subtitle.
- Deletion pre-check: refuses immediately if children known in current list rather than asking then refusing (repository still guards, including hidden archived children).

**`CategoryFormScreen`**: full screen (not bottom sheet), create/edit fields: name (validated), parent picker (blocked set excludes category + descendants), icon grid (24 icons from `categoryIcons` map), color grid (12 from palette). Reads all non-archived categories to build parent picker and determine ineligible set. FAB to create.

**`category_picker.dart`**: `pickCategory(context, {selected, allowNone})` returns `Future<CategoryPick?>`. Bottom sheet over whole tree with every node expanded, any node selectable (leaf or non-leaf). Returning null means dismissed; returning `CategoryPick(null)` means deliberately cleared—this distinction is load-bearing. `allowNone` controls whether a "Keine Kategorie" option appears.

**`category_chip.dart`**: `CategoryChip({categoryUuid, onTap})` compact label for transaction rows and import previews. Reads the archived list so a transaction pointing at an archived category still renders. Shows `—` when uncategorized, `?` if uuid points nowhere.

**`category_style.dart`**: 
- `categoryIcons` map (24 keys: `label`, `shopping_cart`, `restaurant`, `local_cafe`, `home`, `bolt`, `water_drop`, `wifi`, `smartphone`, `directions_car`, `local_gas_station`, `train`, `medical_services`, `fitness_center`, `school`, `child_care`, `pets`, `movie`, `sports_esports`, `card_giftcard`, `savings`, `payments`, `receipt_long`, `shield`). Keys are persisted; never rename.
- `categoryPalette` list (12 hex colors: red, pink, purple, indigo, blue, teal, green, amber, orange, brown, grey).
- Helpers: `categoryIcon(name)` (fallback to `label`), `categoryColor(hex)` (fallback to `#607D8B`).

## Navigation
From `AccountListScreen` app bar: category icon button → `CategoryTreeScreen`.

## Not in scope here
- Fractal line-item category override (ticket 012)
- Import/export of category presets
