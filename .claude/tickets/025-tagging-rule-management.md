# Tagging rule management

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Auto-Tagging |
| **Domain** | Tagging |
| **Blocked By** | 013 |
| **Status** | Ready |

## Description
Make the rules learned by ticket 013 visible and editable. Split out of 013, which shipped storage plus the learn hook but left the rules invisible: there is no Settings surface in the app yet, and building one as a by-product of a storage ticket would have designed it by accident.

Scope boundary: 013 owns `TaggingRule`, `TaggingRuleRepository` (including `delete` and `remap`, already shipped) and `TaggingLearnService`. This ticket owns **only** the screens. No new domain logic is expected — if an AC below needs a repository method that does not exist, that is the signal to re-check the boundary.

## Scope boundary against 024
024 lands first and **builds** `SettingsScreen` plus its own `Import-Historie` row. This ticket **adds** the
`Tagging-Regeln` row and the rule screen behind it. Cut line: the container belongs to 024, everything about rules to
this ticket. If 025 were ever implemented first, it inherits the container work and 024 loses it.

## Resolved during refinement
- **Entry point** → inherited from 024, which lands first and builds `SettingsScreen` under a `Mehr` → `Einstellungen`
  tile. This ticket adds one `Tagging-Regeln` row to that screen and nothing else about the container
- **Stale definition** → both reachable-in-principle states share one marker: the category uuid resolves to nothing, or
  it resolves to an `archived` category. That is a single null-check in the same mapping, not a second code path. Only
  the archived case gets a test; a dangling uuid needs a raw Isar write past the repository, and `Category.delete` is a
  soft delete, so no allowed path produces it (same reasoning as the dropped empty-key guard in `decisions.md`)
- **List shape** → flat, default `hitCount` DESC (the order `findAll` already returns), switchable to `lastAssignedAt`
  and counterparty. No grouping and no conflict badge: rules competing for one counterparty land next to each other in
  the counterparty sort for free, and grouping would make the strength sort meaningless across sections
- **Manual creation** → out. Rules are born in the learn path from 013; this screen only curates. A hand-typed
  `matchValueNorm` would have to guess what `normalizeForMatching` produces, and a mistyped rule never matches without
  anything in the UI saying so. Picking from existing counterparties was rejected too: it needs a distinct-counterparty
  query that does not exist, which would break this ticket's "screens only" boundary
- **Stale handling** → per-row remap through the category picker (`remap` keeps `hitCount`), plus exactly one collective
  `Veraltete Regeln löschen` action with a confirm showing the count. No multi-select mode: stale rules appear in batches
  when a category is archived, so bulk *delete* earns its place while remapping stays a case-by-case decision

## Acceptance Criteria
- [ ] `SettingsScreen` gains one `Tagging-Regeln` row pushing the rule screen; nothing else on that screen changes
- [ ] Rule list is flat, default `hitCount` DESC then `lastAssignedAt` DESC (the `findAll` order), switchable to
      `lastAssignedAt` and counterparty; comparators live in Dart, not in a query
- [ ] Row shows `matchValueNorm`, the resolved category name, `hitCount`, `lastAssignedAt`
- [ ] Category names resolve through `categoriesProvider` with `includeArchived: true`, so an archived category still
      renders its name next to the stale marker
- [ ] A rule's category can be changed via the existing category picker, calling
      `TaggingRuleRepository.remap(uuid, categoryUuid)`; `hitCount` survives
- [ ] Single-rule delete calls `TaggingRuleRepository.delete(uuid)` behind a confirm
- [ ] Stale marker on every row whose `categoryUuid` resolves to nothing or to an `archived` category
- [ ] One collective `Veraltete Regeln löschen` action, confirm dialog names the count, removes only stale rules
- [ ] No way to create a rule by hand anywhere on the screen
- [ ] Empty state when nothing has been learned yet
- [ ] List is reactive (`StreamProvider` on the Isar collection watch, like `accountsProvider`): remap and delete are
      reflected without a manual refresh
- [ ] Archiving a category leaves its rules in place — covered by a test
- [ ] No new repository method is added. Needing one means the boundary against 013 is drawn wrong
- [ ] `make check` green

## Affected Tests
- `test/features/tagging/presentation/tagging_settings_test.dart` — list, the three sorts, remap keeping `hitCount`,
  single delete, stale marker for an archived category, collective delete hitting only stale rows, empty state
  (the file ticket 013 could not write)

## Fixtures Needed
No. A handful of `TaggingRule` rows plus one archived category, built inline in the test — same call as 024.

### Refinement Tokens (estimate)
- Input: ~26k tokens
- Output: ~3k tokens

### Implementation Tokens (estimate)
_Filled after Done._
