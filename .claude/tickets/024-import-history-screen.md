# Import history screen

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Import |
| **Domain** | Import |
| **Blocked By** | 009 |
| **Status** | Draft |

## Description
Split out of ticket 009, which specified this list "under Settings" — but no
Settings surface exists in the app, so it was a hidden second feature inside a
dedupe ticket.

Shows the `ImportedSource` rows written by every import (PDF today, receipt
photos from ticket 016 onwards) and lets the user delete them. Deleting a row is
the escape hatch for the re-import warning: after a legitimate re-import, the
user can drop the record so the warning stops firing.

## Open questions for refinement
- Where does it live? A real Settings screen (also wanted for the App-Lock
  ticket named in `decisions.md`) or an action on the import entry point?
- Does deleting an `ImportedSource` row also need to touch the transactions that
  import produced, or is it purely a history entry?
- Sort and grouping: flat list by `importedAt DESC`, or grouped by month?
- Show `transactionsProduced` / `lineItemsProduced` counts per row, and does
  tapping a row lead anywhere?
- Is a "delete all history" action wanted, or is per-row enough?

## Acceptance Criteria
_Not refined yet — the open questions above must be answered first._

## Out of Scope
- Anything that re-runs or undoes an import
- Storing the raw documents themselves (project-wide decision: never persisted)

## Fixtures Needed
Ask during refinement.

## Token Usage
_Filled after Done._
