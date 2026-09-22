---
title: "Only an unambiguous article rule fills a row unattended; a tie fills nothing"
date: 2026-09-22
tags:
  - adr
description: "unambiguousSuggestion accepts a single candidate or a strongest one with a strictly higher hitCount, and is shared by the scan review and the line-item sheet. A tie left filled silently would teach the loser away at confirm, because an untouched suggestion is reported as a guess and the chosen one is not."
---

# 0154 — Only an unambiguous article rule fills a row unattended; a tie fills nothing

**Status:** Accepted, 2026-09-22

## Context
A photographed Picnic receipt yields nineteen positions (ticket 055). Offering a suggestion the
user has to tap per row would halve nothing — the point of ticket 056 is that rows arrive filled.
So filling happens automatically, which raises the question of what to do when the rules do not
agree.

They frequently will not. `Milch` may have been filed under *Einkauf* twice and under *Getränke*
twice, and `suggest` returns both, ordered by `hitCount`. Taking the head regardless would pick
whichever tied rule sorted first — in practice the one assigned more recently, which is a
tiebreaker meant for display order, not for a decision.

That would be worse than leaving the row empty, and not only cosmetically. An untouched
suggestion is reported to the learn hook as a guess and teaches nothing, while a row the user
corrects teaches the correction. So a silently filled tie that the user does not notice leaves
both counts untouched, and one the user *does* correct raises only the other side — the wrong
half of a coin flip gets reinforced by the user's cleanup, not by their intent.

## Decision
`unambiguousSuggestion(ordered)` returns a suggestion only when there is a single candidate
category, or when the strongest one's `hitCount` is **strictly** greater than the runner-up's.
Otherwise it returns null and the row stays as it was — inheriting the booking's category.

The marker still appears for a tie in the sense that the alternatives are recorded and reachable;
what does not happen is the fill.

One function, used by both the scan review and the line-item sheet, so "unambiguous" cannot come
to mean two different things on two surfaces.

## Consequences
A first-ever assignment for an article fills immediately, since one candidate is unambiguous by
definition. A genuinely contested article stays empty until the user breaks the tie once by hand,
after which it fills from then on. That is the behaviour worth having: the ambiguity is resolved
by the person who knows, exactly once.

Nothing further down the ordered list can break a tie at the top — a third rule with one hit does
not make a 2–2 split decidable.

## Evidence
- `lib/features/tagging/domain/tagging_suggest_service.dart` — `unambiguousSuggestion`
- `lib/features/drilldown/scan/domain/receipt_scan_flow_controller.dart` — `_withSuggestions`,
  the scan side
- `lib/features/drilldown/presentation/line_item_edit_sheet.dart` — `_suggestCategory`, the
  sheet side
- `test/features/tagging/domain/tagging_suggest_service_test.dart` — group
  `unambiguousSuggestion (ticket 056)`, including that a tie is not decided further down
- `test/features/drilldown/scan/domain/receipt_scan_suggest_test.dart` — `a tie fills nothing but
  still offers both alternatives`
