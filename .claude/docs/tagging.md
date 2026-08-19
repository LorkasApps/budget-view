# Tagging (Tagging domain)

Learns which category the user assigns to a counterparty; the suggest service consumes rules to rank candidate categories. `lib/features/tagging/`. No UI yet — rules are invisible until ticket 025.

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

Read at the call sites, so no app-bootstrap wiring is involved.

## Not in scope here
- Rule list / edit / delete / stale handling (ticket 025)
- Learning from line-item level assignments — MVP learns from bookings only
