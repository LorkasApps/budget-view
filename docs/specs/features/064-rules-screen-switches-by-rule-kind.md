# The rules screen switches between recipient and article rules

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Auto-Tagging |
| **Domain** | Tagging |
| **Blocked By** | 056 |
| **Status** | Draft |

## Description
Split out of ticket 056, which teaches tagging to key a rule on an article description rather than a counterparty. Once that
lands, `TaggingRulesScreen` shows both kinds in one flat list — `h-milch 1,5 %` beside `REWE Berlin` — and the handful of
counterparty rules drown under hundreds of article rules. That devalues the surface ticket 025 just built.

The decision itself was taken during 056's refinement and carries over unchanged: **one list with a switch by kind**
(`Empfänger` / `Artikel`). Both kinds need the same curating, so a second settings entry would only bloat the menu, and doing
nothing is what drowns the list.

**Scope boundary against 056.** 056 owns the mechanism: the field-aware lookup, learning from a position, the suggestion in the
review screen and in the line-item sheet. 064 owns the curating surface. The cut line is `TaggingRulesScreen` — 056 may write
and read article rules, but changes nothing about how they are listed or curated.

Deliberately after 056 rather than with it: the switch can then be built against real article rules instead of imagined ones,
and an empty `Artikel` side is a state worth seeing before deciding how it should read.

## What already fits
- **No new query.** `taggingRulesProvider` is a `StreamProvider` over `findAll()`, and the screen already sorts in Dart because
  the table is small and the ordering rule should live in one readable place (`tagging.md`). Filtering by `matchField` belongs in
  the same place, on the list the provider already yields
- **The field is already stored.** `TaggingRule.matchField` is part of the composite unique index, so every rule can already say
  which kind it is — no migration, no `kDbSchemaVersion` bump
- **Curating is kind-agnostic.** `remap` and `delete` key on the rule's uuid and never look at the match field, so tapping a row,
  swiping it away and the stale-rule banner should all keep working untouched

## Open questions for refinement
- **What control?** A `SegmentedButton`, tabs, or filter chips. The header already carries the sort menu ("Stärke",
  "Zuletzt genutzt", "Gegenseite"), so this is a second control in the same row and the interaction between them matters
- **Does the sort menu stay as it is?** "Gegenseite" is counterparty vocabulary. On the `Artikel` side the same sort is by
  article term, and the label may have to change per kind — or be renamed once for both
- **What does an empty `Artikel` side say?** It is the normal state right after 056 lands, not an error, and the existing empty
  state is worded for the whole screen
- **Which kind opens first?** `Empfänger` is the older and smaller set; `Artikel` will be the larger one
- **Do the counts belong on the switch?** `Empfänger 12` / `Artikel 340` would answer "where is everything" before a tap, but it
  is another thing to keep correct

## Acceptance Criteria
- [ ] `TaggingRulesScreen` shows `Empfänger` and `Artikel` rules separately, in one screen, via a switch
- [ ] Curating works unchanged on both sides: tap to remap, swipe to delete, and the stale-rule banner
- [ ] The sort menu keeps working on whichever side is shown
- [ ] Filtering happens in Dart over `taggingRulesProvider`, with no new repository query and no schema change
- [ ] An empty side reads as a normal state rather than an error
- [ ] `make check` green

## Out of Scope (proposed, to confirm)
- Anything about how article rules are learned or suggested — that is 056
- Hand-creating a rule, which ADR 0105 rules out for both kinds
- Multi-select or bulk curating beyond the existing stale-rule banner

## Affected Tests
- The `TaggingRulesScreen` widget tests gain the switch, and at least one asserting that a rule of the other kind is absent from
  the shown side

## Fixtures Needed
Ask during refinement.

### Refinement Tokens (estimate)
_Filled after refinement._

### Implementation Tokens (estimate)
_Filled after Done._
