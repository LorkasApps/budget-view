# Back from any tab closes the app

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | None |
| **Domain** | Infra |
| **Blocked By** | None |
| **Severity** | Medium |
| **Status** | Ready |

## Description
`AppShell` switches three tabs over an `IndexedStack`. The stack has no navigation history of its own, so the system back
gesture at tab root has nothing to pop and closes the app — from `Report` and from `Mehr` just as from `Konten`.

That deviates from what Android users expect: back from a secondary bottom-nav destination returns to the start
destination, and only back from there leaves the app. Here every tab is an exit door. Found in the ticket 028 device pass,
by swiping back out of a tab and landing on the home screen.

The `IndexedStack` is deliberate — it is what keeps each tab's scroll position and filters alive across switches (029).
This ticket is about the history that sits *around* it, not about replacing it.

## Repro Steps
1. Open the app, switch to `Report` or `Mehr`
2. Swipe back (or press the system back button)
3. The app closes instead of returning to `Konten`

## Expected vs Actual
- **Expected:** back from a non-start tab returns to `Konten`; back from `Konten` leaves the app
- **Actual:** back from any tab leaves the app

## Affected Envs
`dev` and `prod` — the behaviour is structural, not build-dependent.

## Workaround
None. The gesture is the platform's, not ours.

## Since When
Since the shell landed (ticket 020, extended by 029). No device pass had happened until 2026-08-20.

## Resolved during refinement
- **History model** → back from a non-start tab selects `Konten`; back from `Konten` leaves the app. The Android convention
  for bottom navigation, a `PopScope` at shell level, and nothing about pushed routes changes. Rejected walking the visited
  tab order (the user cannot tell how deep they are, and three tab switches meaning three back presses reads as the app
  refusing to close) and rejected a `Navigator` per tab, which is a shell rebuild rather than a fix: pushed screens would
  then live inside the tab and the nav bar would stay visible where it is covered today
- **Leaving the app** → no confirmation, no double-tap. Nothing is at stake: bookings and positions save immediately, unsaved
  input only exists in pushed forms, and those never reach this point under the chosen model. Accepted cost: an accidental
  swipe closes the app — which restarts in under a second with its state intact
- **Predictive back** → in scope: `android:enableOnBackInvokedCallback` is switched on as part of this change. That makes it
  an app-wide behaviour change rather than a shell fix, so the device checks below belong to this ticket. Note the
  interaction: a `PopScope` that intercepts the pop suppresses the preview animation for exactly that gesture, so the tab
  root will not animate even with the flag on

## Acceptance Criteria
- [ ] Back at the root of `Report` or `Mehr` selects `Konten` instead of closing the app
- [ ] Back at the root of `Konten` closes the app, with no dialog and no double-tap
- [ ] Pushed routes keep popping as before — nothing about `Einstellungen` → list → back changes
- [ ] The `IndexedStack` still keeps each tab's scroll position and filters across switches (the reason it exists)
- [ ] `android:enableOnBackInvokedCallback="true"` in the manifest
- [ ] Widget test at shell level: select a tab, invoke the pop, assert the selected index changed to `Konten`; a second pop
      from `Konten` reports that the route may pop. Whether the process exits is the platform's business, not an assertion
- [ ] `make check` green

## Device checks (predictive back touches every route)
- [ ] Tab root: gesture returns to `Konten`, and no half-finished preview animation is left on screen
- [ ] Pushed screen (`Import-Historie`, `Tagging-Regeln`, forecast, trends): the gesture shows the preview and pops
- [ ] Bottom sheets — category picker, line-item sheet: the gesture dismisses the sheet, not the screen behind it
- [ ] Dialogs — quick-create, every confirm dialog: the gesture cancels the dialog and writes nothing
- [ ] A booking form with unsaved input: the gesture must not make discarding easier than it is today
- [ ] Scan review with candidates: the gesture does not silently drop a reviewed list

## Affected Tests
- A widget test can drive back at shell level: pump `AppShell`, select a tab, invoke the pop and assert the selected index
  rather than the process state. Whether the app actually exits is the platform's business, not something a test asserts
- The existing shell test around `IndexedStack` state retention must stay green

## Fixtures Needed
No.

### Refinement Tokens (estimate)
- Input: ~12k tokens
- Output: ~2k tokens

### Implementation Tokens (estimate)
_Filled after Done._
