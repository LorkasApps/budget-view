# Tagging (Tagging domain)

Learns which category the user assigns to a counterparty; the suggest service consumes rules to rank candidate categories. `lib/features/tagging/`. Rules are curated via `TaggingRulesScreen` (ticket 025).

## Entity — `TaggingRule` (`data/tagging_rule.dart`)
Implements `SyncableEntity` (`entityType = 'taggingRule'`).

| Field | Type | Notes |
|-------|------|-------|
| `id` | Id | Isar auto-inc, internal |
| `uuid` | String | UUID v4, unique index |
| `matchValueNorm` | String | Normalized match value. **Composite unique index** with `matchField` + `categoryUuid` |
| `matchField` | `TaggingMatchField` | `counterparty` \| `description`, stored by name. Only `counterparty` is learned today |
| `categoryUuid` | String | FK to `Category.uuid`. Never validated — a stale rule is a legal state (ticket 025 surfaces it) |
| `hitCount` | int | Confidence: re-assigning the same pair raises it. Default 1 |
| `lastAssignedAt` | DateTime | Set on create and on every increment |
| `createdAt` / `updatedAt` | DateTime | Maintained by repo |

One counterparty may hold rules for several categories — each keeps its own count, and the strongest wins on suggestion.

## Repository — `TaggingRuleRepository` (`domain/tagging_rule_repository.dart`)
| Method | Sync op |
|--------|---------|
| `upsert(matchValueNorm, categoryUuid, {matchField})` | create (new pair) / update (`hitCount += 1`, `lastAssignedAt` refreshed) |
| `findByCounterparty(matchValueNorm)` | — strongest first: `hitCount` DESC, then `lastAssignedAt` DESC |
| `findAll()` | — same ordering |
| `findByUuid(uuid)` | — |
| `delete(uuid)` | delete — **hard delete**, no archive flag: a rule that lingers keeps suggesting, so removal *is* the domain operation (same reasoning as `ImportedSource`) |
| `remap(uuid, categoryUuid)` | update — moves a rule to another category, keeping its learned `hitCount`. Backs ticket 025's stale-rule cure |

Sorting happens in Dart, not in a query: the table is small and it keeps the ordering rule in one readable place.

## Learn service (`domain/tagging_learn_service.dart`)
`TaggingLearnService(repository).learnFrom(Transaction)` — a no-op unless all three hold:

| Condition | Reason |
|-----------|--------|
| `categoryUuid != null` | nothing to learn from an uncategorized booking |
| `categoryAutoSuggested == false` | an accepted suggestion would only reinforce itself |
| normalized `counterparty` non-empty | no reliable signal to match on |

Normalization is `normalizeForMatching` from `lib/core/text/normalize.dart` — the same function the dedupe hash uses, deliberately shared so a rule matches exactly what dedupe considers the same counterparty.

**Call sites** (`learnFrom` is called by the UI, never by a repository hook — see decisions.md):

| Where | When |
|-------|------|
| `TransactionFormScreen._save` | manual entry or edit |
| `TransactionListScreen` row quick-pick | inline category reassignment |
| `ImportFlowController.persist` | once per imported row — a statement is a bulk teaching opportunity |

The first two also reset `Transaction.categoryAutoSuggested` to `false`, because a hand-picked category is no longer a suggestion.

## Suggest service (`domain/tagging_suggest_service.dart`)

- `CategorySuggestion` — `categoryUuid`, `categoryName` (carried so suggestion renders
  without second lookup), `hitCount` (bare count is the confidence story).
- `TaggingSuggestService` interface + `LocalTaggingSuggestService
  (taggingRuleRepository, categoryRepository)`. One method:
  `Future<List<CategorySuggestion>> suggest(String counterparty)`.
- Normalizes the counterparty itself via `normalizeForMatching`, so callers hand in
  raw field value.
- Blank counterparty → `const []`. No rules → `const []`.
- Order from `findByCounterparty` (`hitCount` DESC, then `lastAssignedAt` DESC).
- Rules whose category is archived or gone are dropped: the category picker offers
  neither, so suggesting it would be an offer the user cannot repeat by hand. A rule
  pointing at an archived category stays a legal stored state (ticket 025 cures it).

## Suggestion sheet (`presentation/suggestion_sheet.dart`)

- `pickSuggestion(context, suggestions, {selectedCategoryUuid})` — modal bottom
  sheet titled `Vorschläge`, at most `maxSuggestionAlternatives` (3) rows. Each row:
  `Icons.auto_awesome_outlined`, category name, trailing `<hitCount>×`. Returns
  tapped suggestion, `null` when dismissed.
- Renders the name the suggestion carries instead of a `CategoryChip`, so the sheet
  needs no category provider.
- Shared by the booking form and the PDF-import preview.

## Providers (`domain/tagging_providers.dart`)
- `taggingRuleRepositoryProvider`
- `taggingLearnServiceProvider`
- `taggingSuggestServiceProvider` (interface-typed, so widget tests can hand in fake)
- `taggingRulesProvider` — `StreamProvider<List<TaggingRule>>`, yields `findAll()` and re-yields on `isar.taggingRules.watchLazy()`. Same shape as `accountsProvider`

Read at the call sites, so no app-bootstrap wiring is involved.

## TaggingRulesScreen (`presentation/tagging_rules_screen.dart`) — ticket 025

Flat list of learned rules, default order strongest-first (`hitCount` desc, then `lastAssignedAt` desc).

**Header sort menu:** "Stärke" (default), "Zuletzt genutzt" (`lastAssignedAt` desc), "Gegenseite" (`matchValueNorm` asc, case-insensitive). Sort order is Dart comparator, not query.

**Row:** leading category icon, title `matchValueNorm`, subtitle joining resolved category name, `<hitCount>×`, date, and `veraltet` when stale. Trailing warning icon only when stale.

**Stale:** rule's `categoryUuid` resolves to nothing OR to a category with `archived == true`. Names resolve via `categoriesProvider(true)` so archived category name still shows.

**Interactions:** tapping opens `pickCategory` sheet and calls `TaggingRuleRepository.remap` (preserves `hitCount`). Swipe end-to-start deletes behind confirm. When stale rules exist, banner above list offers collective delete (names the count, removes only stale). No multi-select.

**Rules never hand-created:** `matchValueNorm` is normalized string (`normalizeForMatching`), so hand-typed value that never matches looks indistinguishable from a working rule. Rules born only in learn path.

## Tests — curation side
| File | Coverage |
|------|----------|
| `test/features/tagging/presentation/tagging_settings_test.dart` | Rows in all three sort orders, stale marker, remap via picker, single delete, collective delete (stale only), empty state |
| `test/features/tagging/domain/tagging_rule_category_archive_test.dart` | Archiving a category leaves its rules in place with their `hitCount`, on a real Isar |

Repository, learn service, suggest service and the sync mirror keep their own suites under `test/features/tagging/domain/`.

## Not in scope here
- Learning from line-item level assignments — MVP learns from bookings only
