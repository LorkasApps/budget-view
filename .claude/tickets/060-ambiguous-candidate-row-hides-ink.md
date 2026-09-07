# An ambiguous candidate row trips a framework assertion

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | None |
| **Severity** | Low |
| **Status** | Draft |

## Description
Opening the scan review with at least one ambiguous candidate throws a framework
assertion, once per such row:

```
ListTile background color or ink splashes may be invisible.
The ListTile is wrapped in a ColoredBox that has a background color. Because
ListTile paints its background and ink splashes on the nearest Material ancestor,
this ColoredBox will hide those effects.
```

Debug-only, and nothing crashes. The visible cost is that the highlighted row
swallows its own tap feedback. The real cost is noise: ten identical exceptions
scroll past in the console of the one screen where OCR problems get diagnosed, and
they can bury the exception that matters. Found while collecting the `OcrResult`
dump for ticket 055 — on that screen, at that moment, exactly the wrong place for
console noise.

## Repro Steps
1. Debug build (`make run`)
2. Open a saved booking → positions section → scan a receipt whose OCR yields at
   least one row without a description (`LineItemParseState.ambiguous`)
3. The review screen (`Erkannte Positionen`) appears — the assertion fires once per
   ambiguous row

## Expected vs Actual
- **Expected:** the row is tinted and still shows its ink splash on tap; no assertion.
- **Actual:** the assertion fires per row, and the splash is painted where nobody sees it.

## Affected Envs
`dev` (debug builds). Assertions are stripped from release, so `prod` shows the
swallowed splash but no error.

## Workaround
None needed — the screen works.

## Since When
Unknown, and worth a moment when fixing. The code is older than the current
toolchain (Flutter 3.44.4), and this assertion is a relatively recent framework
addition, so the likelihood is that a Flutter upgrade started reporting a
long-standing pattern rather than that a change introduced it. `git log` on
`scan_review_screen.dart` against the Flutter bump would settle it.

## Cause
`_CandidateRow` (`lib/features/drilldown/scan/presentation/scan_review_screen.dart`,
lines 291-293):

```dart
return Container(
  color: ambiguous ? theme.colorScheme.tertiaryContainer : null,
  child: ListTile(...),
);
```

A `Container` with a colour and no other decoration compiles to a `ColoredBox`,
which sits between the `ListTile` and the `Material` it paints its ink on.

## Proposed fix, to confirm during refinement
`ListTile` already owns this: `tileColor` paints through the Material ancestor
instead of over it. Dropping the `Container` and moving the colour onto the tile
removes both the assertion and one widget from the tree:

```dart
return ListTile(
  tileColor: ambiguous ? theme.colorScheme.tertiaryContainer : null,
  ...
);
```

The alternative the framework message suggests — wrapping the tile in its own
`Material` — adds a widget to keep a `Container` that was never needed.

## Acceptance Criteria
- [ ] An ambiguous candidate row is still tinted, and tapping it shows an ink splash
- [ ] No framework assertion when the review opens with one or more ambiguous rows
- [ ] A non-ambiguous row is unchanged
- [ ] `make check` green

## Affected Tests
The gap that let this through: no widget test renders a `_CandidateRow` whose
`parseState` is `ambiguous`, or the assertion would have failed the suite rather
than waiting for a device. A test that renders one is the actual regression guard
here — more valuable than the fix.

## Fixtures Needed
No. One ambiguous candidate built inline.

### Refinement Tokens (estimate)
_Filled when it reaches Ready._

### Implementation Tokens (estimate)
_Filled after Done._
