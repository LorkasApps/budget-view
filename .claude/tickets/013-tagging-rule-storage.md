# Tagging rule storage

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Auto-Tagging |
| **Domain** | Tagging |
| **Blocked By** | 011 |
| **Status** | Done |

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
- [x] `TaggingRule` Isar collection defined in `lib/features/tagging/data/tagging_rule.dart`
- [x] `TaggingRuleRepository` in `lib/features/tagging/domain/`: `upsert(counterpartyNorm, categoryUuid)`, `findByCounterparty(counterpartyNorm) → List<TaggingRule>` (sorted `hitCount DESC`, then `lastAssignedAt DESC`), `delete(uuid)`, `findAll` — plus `remap(uuid, categoryUuid)`, which ticket 025 needs and which belongs to the storage layer
- [x] `save` / `upsert` / `delete` route through `syncAdapter.enqueue(...)`
- [x] `TaggingLearnService`: on user-driven category assignment with non-empty counterparty → calls `upsert`. **Called from the three UI paths** (booking form, inline quick-pick in the list, import persist loop), **not** as an observer inside `TransactionRepository.save` — a hook there would have inverted the documented `Tagging → Transaction` direction, same reasoning as ticket 019's reconciler. See decisions.md
- [x] User-driven vs auto-suggested distinguished: `Transaction.categoryAutoSuggested` added here; the learn hook skips `true`. Nothing writes `true` until 014 lands, and the two UI paths where the user picks a category reset it to `false`
- [x] Reuse ticket 009's normalization utility (`normalizeForMatching`, single implementation)
- [x] `taggingRuleRepositoryProvider` (Riverpod) exposes repo
- [x] `taggingLearnServiceProvider` (Riverpod) exposes service — read at the call sites, so no bootstrap wiring is needed
- [x] Deleting a category does NOT cascade-delete rules — nothing in the category feature touches tagging, so stale rules simply survive. **Surfacing and curing them is ticket 025**
- ➜ **Moved to ticket 025**: the Settings screen with the sortable rule list, edit, delete, stale marker and the remap / delete-stale batch actions. There is no Settings surface in the app yet, and building one as a side effect of a storage ticket would have designed it by accident

## Entity Change on `Transaction`
Add:
| Field | Type | Notes |
|-------|------|-------|
| `categoryAutoSuggested` | bool | Default `false`. Set to `true` when suggestion accepted verbatim in ticket 014. Reset to `false` if user changes category afterwards. |

## Affected Tests
- `test/features/tagging/domain/tagging_rule_repository_test.dart` — upsert semantics, hit-count, one counterparty across two categories, `findByCounterparty` ordering + field filter, delete, remap (8 tests)
- `test/features/tagging/domain/tagging_learn_service_test.dart` — normalization, and the three cases that teach nothing: no category, empty counterparty, accepted suggestion (7 tests)
- `test/features/tagging/domain/tagging_sync_integration_test.dart` — enqueue on create / update / delete / remap, filtered by `entityType` (4 tests)
- ~~`test/features/tagging/presentation/tagging_settings_test.dart`~~ — **moved to ticket 025** with the screen it covers

Suite after the ticket: 245 passed, 0 failed, 2 skipped (was 226).

`kDbSchemaVersion` stays at 3: the new collection is additive, and the new `bool` on `Transaction` reads as `false` on existing rows — which is the intended default. A bump would only nuke local test data.

Not verified: no emulator run. There is nothing to look at yet either — rules are invisible until 025.

## Fixtures Needed
No — inline builders.

## Refinement Tokens (estimate)
- Input: ~10k tokens
- Output: ~3k tokens

### Implementation Tokens (estimate)
- Input: ~120k tokens (~82k of it the delegated test pass on Sonnet)
- Output: ~13k tokens
