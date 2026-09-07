# Word search and a category filter in the account's booking list

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | None |
| **Domain** | Transaction |
| **Blocked By** | None |
| **Status** | Done |

## Description
The booking list of an account offers exactly one way to narrow itself down today: the `Nur ohne Kategorie` toggle. Finding a
specific booking means scrolling. Wanted: a **word search** and a **category filter**.

## Precedents that should decide the details
- **Search semantics are already settled once.** Ticket 038 gave the category picker a case-insensitive substring search and
  deliberately rejected `normalizeForMatching`, because that function exists for machine comparison in dedupe and tagging and
  widening it would silently change what search does. Umlauts stay literal there, so `Bruehe` does not find `Brühe` — a second
  search in the same app should behave the same way or the app has two answers to one question
- **A category filter is a subtree question, not a row question.** The report drills into a category *including* its children
  (`decisions.md`, 2026-08-18). Picking `Lebensmittel` in a list filter and not seeing the `Getränke` bookings would read as a
  bug, and ticket 051 (one sub-level only) does not change that, it just bounds the depth
- **The merchant is now visible in the row** (ticket 047): the list shows `merchant ?? counterparty`, so search has to cover
  what the user sees, not only what the bank wrote
- **Ticket 049** is about transfers clogging the existing uncategorized filter. If this ticket rebuilds the filter row, the two
  overlap — 049 may end up folded in here or become redundant

## Resolved during refinement
- **The filter replaces the toggle.** `Nur ohne Kategorie` goes; `Ohne Kategorie` becomes one option of the category filter,
  `Alle Kategorien` its neutral one. Two controls that both narrow by category are one too many. The user's own note: the
  toggle is used often today and will be used rarely once enough data is in. **Ticket 049 is thereby folded in** — its rule
  (transfers do not show under `Ohne Kategorie`) lives in that option
- **Search covers** `description`, `counterparty`, `merchant`, `note` **and the formatted amount**. `merchant` has to be in it
  because the row shows it instead of the counterparty since 047 — one would otherwise search for what one sees and find
  nothing. The amount is in because "wo war die 104,97?" is a natural search; accepted cost: `50` matches a lot, and a search
  for `12,50` also hits a description containing it. Semantics as in 038: case-insensitive substring, umlauts literal
- **One category, including its children.** The report has drilled into a category plus its subtree since 020, so picking
  `Lebensmittel` and not seeing `Getränke` bookings would read as a bug. Multi-select was dropped: it costs UI and raises a
  second question (union of subtrees) for little gain on a single account's list
- **The balance header does not react.** It is a *balance* — opening balance plus every booking — not a list total, and making
  it follow the filter would both change what it means and contradict the figure in the account list. Sums are the report's
  job (020, and now 052)
- **Filtering happens in memory**, as a pure predicate over the account's already-streamed bookings. Decisive reason is
  testability: substring over five fields, a category subtree, and `Ohne Kategorie` excluding transfers are plain Dart this
  way, unit-testable and usable in widget tests, while an Isar query would need real Isar — which never completes inside
  `testWidgets` (`decisions.md`, 2026-08-12). Accepted cost: the work grows with the account's history; moving the predicate
  into a query later is a contained change, and ticket 059 gives that boundary a natural shape
- **No persistence.** The account list is a pushed screen, not a tab, so its state ends with it. A filter that still bites on
  the next visit is the kind of state one forgets and then mistakes for missing data
- **Empty state carries the reset.** `Keine Buchung passt zu Suche und Filter.` with a `Filter zurücksetzen` action, plus the
  clear cross in the search field as in 038. No permanently visible reset button. **The month of ticket 059 is not a filter**
  and this action must not touch it — one month is always shown

## Acceptance Criteria
- [x] A search field narrows the list: case-insensitive substring, umlauts literal, over `description`, `counterparty`,
      `merchant`, `note` and the formatted amount
- [x] A category filter offers `Alle Kategorien`, `Ohne Kategorie`, and one category at a time **including its children**
- [x] Under `Ohne Kategorie`, transfers do not appear (this is ticket 049's rule; 049 closes with this)
- [x] The standalone `Nur ohne Kategorie` toggle is gone
- [x] Search and category combine with AND
- [x] The balance header is unchanged in every state — no filtered sum, no count
- [x] The predicate is a pure function, tested without Isar; the screen only feeds it
- [x] Leaving the account and returning starts with an empty search and `Alle Kategorien`
- [x] With no match: `Keine Buchung passt zu Suche und Filter.` and a `Filter zurücksetzen` that clears search and category
      only
- [x] `make check` green

## Out of Scope (proposed, to confirm)
- Searching across accounts — this is the per-account overview
- Filtering by date range or amount range; that is a different ticket if it is wanted at all

## Affected Tests
- The booking-list widget tests: search narrows, filter narrows, both together, and the existing uncategorized behaviour
  (whatever it becomes) keeps holding

## Fixtures Needed
No. Bookings built inline, plus a two-level category tree for the subtree case.

### Refinement Tokens (estimate)
- Input: ~14k tokens
- Output: ~2.5k tokens

### Implementation Tokens (estimate)
- Input: ~60k tokens
- Output: ~9k tokens
- Delegated: ~153k tokens total for the test-writing sub-agent (Sonnet), which
  wrote both new suites and extended `category_tree_test.dart`

## How it was built
- **`TransactionFilter` (`domain/transaction_filter.dart`)** is the whole rule: a
  pure predicate with `matches`, `apply` and `isActive`. `CategoryFilter` is a
  three-state value (`all` / `without` / `subtree`) that carries the picked
  `rootUuid` beside the resolved `uuids`, so the control can label and tick
  itself without re-deriving which uuid was the root.
- **Search covers both spellings of the amount.** `formatCentsEur` prints
  `1.234,56 €`, but a user types `1234,56` and the grouping dot would swallow the
  match, so `formatCentsPlain` is searched too. Found while calibrating, not in
  review.
- **`subtreeUuids` was extracted from `ineligibleParents`**, which now delegates
  to it. The fixpoint walk over `parentUuid` was already exactly the subtree the
  filter needed — it only carried a name about parent eligibility. One owner
  instead of a copy.
- **The filter sheet is its own (`presentation/category_filter_sheet.dart`)**,
  not `pickCategory`. That sheet carries quick-create, and creating a category
  while narrowing a list is a different intent; here all three states are rows of
  one list, so the neutral option is visible instead of hiding behind a clear
  button.
- Known shape of the widget tests: `CategoryChip` in a booking row renders the
  same text as a sheet row and the filter chip, so `find.text` is ambiguous on
  this screen. The tests scope taps to `find.descendant(of: BottomSheet)` and
  read the chip label through `tester.widget<InputChip>`.
