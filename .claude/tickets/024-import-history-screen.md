# Import history screen

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Import |
| **Domain** | Import |
| **Blocked By** | 009 |
| **Status** | Done |

## Description
Split out of ticket 009, which specified this list "under Settings" — but no
Settings surface exists in the app, so it was a hidden second feature inside a
dedupe ticket.

Ticket 025 (tagging rule management) was split off for the very same reason and
needs the same container. The entry-point decision was taken once for both; see
the scope boundary and the resolved section below.

Shows the `ImportedSource` rows written by every import (PDF today, receipt
photos from ticket 016 onwards) and lets the user delete them. Deleting a row is
the escape hatch for the re-import warning: after a legitimate re-import, the
user can drop the record so the warning stops firing.

## Scope boundary against 025
This ticket lands first, so it **builds** `SettingsScreen` and adds the `Import-Historie` row. 025 only **adds** its
`Tagging-Regeln` row to the existing screen. Cut line: everything about tagging rules is 025, including the row itself.

## Resolved during refinement
- **Entry point** → a real Settings screen, reached from one `Einstellungen` tile in `MenuScreen`. It carries one row per
  surface: `Import-Historie` (this ticket), `Tagging-Regeln` (025), later the App-Lock toggle. Chosen over hanging both
  lists straight onto the `Mehr` tab so configuration keeps one home instead of preferences and data lists drifting
  apart once App-Lock arrives. Accepted cost: three levels (`Mehr` → `Einstellungen` → list) for today's two rows
- **Delete semantics** → the row is history only: deleting it silences the re-import warning and touches nothing else.
  The confirm dialog states that the imported bookings stay. A cascade was rejected because `ImportedSource` stores
  counts, not references to what it produced — an undo would first need a new link, which is a ticket of its own and
  contradicts this one's Out of Scope
- **List shape** → flat, `importedAt DESC`. No decision needed: `ImportedSourceRepository.findAll` already returns that
  order, and month headers would be grouping for its own sake on a list that stays short
- **Row content** → date, source (filename for `pdf`, a photo label for `kind=photo` since captures carry no filename),
  `transactionsProduced` / `lineItemsProduced`, and `note` when set. Those counter fields exist for this screen
- **Row tap** → rows are not tappable; delete is the only action. A detail view would repeat the row, because
  `ImportedSource` holds no reference to the bookings it produced and the hash means nothing to the user

## Acceptance Criteria
- [x] `SettingsScreen` exists and is reached from a new `Einstellungen` tile in `MenuScreen`, pushed as a route so back
      returns to `Mehr`
- [x] `SettingsScreen` carries one `Import-Historie` row that pushes the history screen; no other row is added here
- [x] History screen lists every `ImportedSource` flat in `importedAt DESC` via a reactive
      `importedSourcesProvider` (`StreamProvider`, re-queries on the Isar collection watch like `accountsProvider`)
- [x] Row shows: formatted `importedAt`, source label (`filename` for `kind=pdf`, a photo label for `kind=photo`, which
      carries no filename), `transactionsProduced` and `lineItemsProduced`, plus `note` when set
- [x] Rows are not tappable
- [x] Per-row delete calls `ImportedSourceRepository.delete(uuid)` behind a confirm dialog that states the imported
      bookings stay
- [x] The list updates after a delete without manual refresh
- [x] Empty state when no import happened yet
- [x] No "delete all" action anywhere on the screen
- [x] Test: deleting a row leaves the transactions and line-items of that import untouched
- [x] Widget test: `pdf` and `photo` rows render their respective source label, the delete flow reaches the repository,
      the empty state shows
- [x] `make check` green

## Out of Scope
- Anything that re-runs or undoes an import
- Storing the raw documents themselves (project-wide decision: never persisted)

## Fixtures Needed
No. The three to four `ImportedSource` rows the screen test needs read clearer inline than behind a
shared fixture.

### Refinement Tokens (estimate)
- Input: ~28k tokens
- Output: ~3k tokens

### Implementation Tokens (estimate)
- Input: ~55k tokens
- Output: ~6k tokens
