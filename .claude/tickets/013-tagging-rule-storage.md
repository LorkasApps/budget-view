# Tagging rule storage

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Auto-Tagging |
| **Domain** | Tagging |
| **Blocked By** | 011 |
| **Status** | Ready |

## Description
Learn from historical **Transaction**-level category assignments. Each rule maps a normalized `counterparty` (exact match) to a `categoryUuid`, tracking a `hitCount` for confidence. Rules are created + updated automatically on every user assignment. Rules are browsable, editable, deletable via a Settings screen.

Line-item-level learning is out of scope here — MVP learns only from transaction-level assignments.

## Entity — `TaggingRule`

| Field | Type | Notes |
|-------|------|-------|
| `id` | int (auto-inc) | Isar internal |
| `uuid` | String | UUID v4 (from `SyncableEntity`) |
| `matchField` | enum | `counterparty` \| `description` — for MVP always `counterparty`; enum leaves room for future field types |
| `matchValueNorm` | String | Normalized (lower, trim, whitespace-collapse), non-empty |
| `categoryUuid` | String | FK to `Category.uuid` |
| `hitCount` | int | Increments on every re-assignment matching this rule; default 1 |
| `lastAssignedAt` | DateTime | Set on create + every increment |
| `createdAt` | DateTime | |
| `updatedAt` | DateTime | |

Composite unique index: `(matchField, matchValueNorm, categoryUuid)`.

## Behavior

- Learning **hook** runs after any `TransactionRepository.save(...)` that includes a `categoryUuid` set by the user (not auto-suggested — see ticket 014's provenance flag).
- If `transaction.counterparty` is empty → **skip learning** (no reliable signal).
- Normalize `counterparty` with the same function used by ticket 009's dedupe hash (reuse it).
- Upsert: find rule matching `(counterparty, counterpartyNorm, categoryUuid)`.
  - If exists → `hitCount += 1`; update `lastAssignedAt`.
  - Else → insert new rule with `hitCount = 1`.
- If the user re-assigns the same transaction from category A to B: a new rule for B is created (or existing incremented); the A-rule stays with its historical count. On suggestion, highest `hitCount` wins per counterparty.

## Acceptance Criteria
- [ ] `TaggingRule` Isar collection defined in `lib/features/tagging/data/tagging_rule.dart`
- [ ] `TaggingRuleRepository` in `lib/features/tagging/domain/`: `upsert(counterpartyNorm, categoryUuid)`, `findByCounterparty(counterpartyNorm) → List<TaggingRule>` (sorted `hitCount DESC`), `delete(uuid)`, `findAll`
- [ ] `save` / `upsert` / `delete` route through `syncAdapter.enqueue(...)`
- [ ] `TaggingLearnService` observes `TransactionRepository.save`; on user-driven category assignment with non-empty counterparty → calls `upsert`
- [ ] User-driven vs auto-suggested distinguished: transactions carry a boolean `categoryAutoSuggested` field (added here, set by 014 when suggestion accepted without change). Learn hook only fires when `false`.
- [ ] Settings screen: `Auto-Tagging` section — list of rules, sortable by `hitCount` / `lastAssignedAt` / `counterparty`; edit (change category), delete
- [ ] Reuse ticket 009's normalization utility (single implementation)
- [ ] `taggingRuleRepositoryProvider` (Riverpod) exposes repo
- [ ] `taggingLearnServiceProvider` (Riverpod) exposes service; wired in app bootstrap
- [ ] Deleting a category should NOT cascade-delete rules — instead, rules pointing to the deleted category become **stale** (indicated in Settings UI with a warning); UI offers "remap to..." or "delete stale rules" batch action

## Entity Change on `Transaction`
Add:
| Field | Type | Notes |
|-------|------|-------|
| `categoryAutoSuggested` | bool | Default `false`. Set to `true` when suggestion accepted verbatim in ticket 014. Reset to `false` if user changes category afterwards. |

## Affected Tests
- `test/features/tagging/domain/tagging_rule_repository_test.dart` — upsert semantics, hit-count, unique index, findByCounterparty ordering
- `test/features/tagging/domain/tagging_learn_service_test.dart` — hook fires only for user-driven, non-empty counterparty
- `test/features/tagging/presentation/tagging_settings_test.dart` — list, edit, delete, stale marker
- `test/features/tagging/domain/tagging_sync_integration_test.dart` — enqueue on writes

## Fixtures Needed
No — inline builders.

## Refinement Tokens (estimate)
- Input: ~10k tokens
- Output: ~3k tokens

## Token Usage
_Filled after Done._
