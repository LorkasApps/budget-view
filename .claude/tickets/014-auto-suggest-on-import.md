# Auto-suggest category on import

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Auto-Tagging |
| **Domain** | Tagging |
| **Blocked By** | 013 |
| **Status** | Done |

## Description
Use stored `TaggingRule`s (from ticket 013) to **suggest** a category for each transaction candidate at import time or during manual entry. Suggestions are **always visible** — never silent auto-fill. User confirms with one tap. If overridden, the rule store updates via the existing learn hook (ticket 013).

## Behavior

- **Trigger for PDF import (ticket 008 preview list):** for every candidate with non-empty `counterparty`, call `TaggingSuggestService.suggest(counterpartyNorm) → List<Suggestion>` sorted `hitCount DESC`.
- **Trigger for manual entry (ticket 006 form):** when the `counterparty` field loses focus (or on submit blur), suggest — pre-fills the category picker with the top suggestion, but user still must confirm the form.
- **Top-1 rendered inline:** category chip + tiny confidence label (`3×`, `12×` — bare hit-count).
- **"See alternatives" affordance:** tap opens a bottom sheet listing top 3 rules by `hitCount`.
- **Provenance flag:** if the user accepts the suggestion verbatim, `transaction.categoryAutoSuggested = true` (from 013). If the user overrides, `categoryAutoSuggested = false` → 013's learn hook writes a rule for the new category.

## Suggestion DTO

| Field | Type |
|-------|------|
| `categoryUuid` | String |
| `categoryName` | String (for display) |
| `hitCount` | int |

## Acceptance Criteria
- [x] `TaggingSuggestService` interface in `lib/features/tagging/domain/tagging_suggest_service.dart`
- [x] Concrete `LocalTaggingSuggestService` — reads from `TaggingRuleRepository.findByCounterparty(...)`, returns list sorted `hitCount DESC`
- [x] `taggingSuggestServiceProvider` (Riverpod) exposes service, overridable in tests
- [x] Uses the shared normalization function from ticket 009
- [x] **PDF-import preview integration:** each row without a user-set category is auto-populated with the top suggestion; category chip renders in suggestion style (dashed border or subtle tint) until user confirms
- [x] Confirming the import (bulk) commits suggested categories; `categoryAutoSuggested=true` for those rows
- [x] Overriding a suggested row before confirm turns off the suggestion style; `categoryAutoSuggested=false`
- [x] **Manual-entry integration:** on counterparty blur, if top suggestion exists → pre-select category in picker with suggestion style; user tap on the picker clears the suggestion style
- [x] "See alternatives" bottom sheet lists top-3 by `hitCount` with the same hit-count label
- [x] If no rule matches → no suggestion, no visual change (fall back to normal empty picker)
- [x] Learn feedback loop verified: overriding a suggestion → 013's learn hook creates/updates rule for the overridden category

## Affected Tests
- `test/features/tagging/domain/tagging_suggest_service_test.dart` — ordering by hitCount, empty counterparty returns nothing, no rules returns empty
- `test/features/transaction/import/domain/import_preview_suggest_test.dart` — suggestions applied, overriding clears provenance flag (ticket said `import/pdf/`; controller suites live under `import/domain/`)
- `test/features/transaction/presentation/manual_entry_suggest_test.dart` — blur triggers suggest, override clears flag
- `test/features/tagging/domain/tagging_learn_feedback_test.dart` — override → new rule created / hit-count updated
- `test/features/transaction/import/import_flow_widget_test.dart` (existing) — now overrides `taggingSuggestServiceProvider` with an empty fake, since the parse step depends on it

## Deviations
- The import preview already had a category surface (row `CategoryChip`, `Für alle`, `setRowCategory`); `import.md` had simply not documented it. 014 therefore added only the suggestion layer plus the `categorySuggested` provenance, not the category UI itself.
- Picking an alternative from the sheet counts as an **override**, not as accepting a suggestion — see decisions.md for why the learn loop needs that.

## Fixtures Needed
No — inline builders.

## Refinement Tokens (estimate)
- Input: ~9k tokens
- Output: ~3k tokens

### Implementation Tokens (estimate)
- Input: ~215k tokens (incl. sub-agents: tests ~118k, docs ~35k)
- Output: ~24k tokens
