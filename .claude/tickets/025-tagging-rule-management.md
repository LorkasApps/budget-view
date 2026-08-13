# Tagging rule management

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Auto-Tagging |
| **Domain** | Tagging |
| **Blocked By** | 013 |
| **Status** | Draft |

## Description
Make the rules learned by ticket 013 visible and editable. Split out of 013, which shipped storage plus the learn hook but left the rules invisible: there is no Settings surface in the app yet, and building one as a by-product of a storage ticket would have designed it by accident.

Scope boundary: 013 owns `TaggingRule`, `TaggingRuleRepository` (including `delete` and `remap`, already shipped) and `TaggingLearnService`. This ticket owns **only** the screens. No new domain logic is expected — if an AC below needs a repository method that does not exist, that is the signal to re-check the boundary.

## Settings surface
Both this ticket and 024 (import history) need a Settings container that does not exist. Whichever lands first builds it; the second one adds a row. Deliberately unrefined here — the entry point (app-bar icon on the account list vs. a bottom-nav destination) is an open question for refinement.

## Acceptance Criteria (draft — not yet locked)
- [ ] Settings surface reachable from the account list, with an `Auto-Tagging` entry
- [ ] Rule list showing counterparty, category, `hitCount`, `lastAssignedAt`
- [ ] Sortable by `hitCount` / `lastAssignedAt` / counterparty
- [ ] Edit a rule's category (uses `TaggingRuleRepository.remap`, keeps the learned `hitCount`)
- [ ] Delete a single rule (`TaggingRuleRepository.delete` — a real delete, no archive)
- [ ] **Stale rules**: a rule whose `categoryUuid` points at an archived or missing category is marked with a warning. Deleting a category must not cascade-delete rules
- [ ] Batch actions on stale rules: "remap to …" and "delete stale rules"
- [ ] Empty state when nothing has been learned yet

## Open Questions for Refinement
- Where does Settings live — app-bar icon on the account list, or a new bottom-nav destination? Affects 024 as well
- Is "stale" only *archived* category, or also a uuid pointing nowhere? The repository never validated the FK, so both states are reachable
- Should the list group by counterparty (several categories per counterparty are legal) or stay flat, ordered by strength?
- Does the user need to *create* a rule by hand, or only curate learned ones?

## Affected Tests
- `test/features/tagging/presentation/tagging_settings_test.dart` — list, sort, edit, delete, stale marker, empty state (the file ticket 013 could not write)

## Fixtures Needed
Ask during refinement.
