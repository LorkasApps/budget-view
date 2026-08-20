# Back from any tab closes the app

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | None |
| **Domain** | Infra |
| **Blocked By** | None |
| **Severity** | Medium |
| **Status** | Draft |

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

## Open questions for refinement
- **Which history model?** Three candidates, in rising order of cost:
  1. Back from a non-start tab selects `Konten`; back there exits. Matches the platform convention, a handful of lines
     in a `PopScope`, and no change to how pushes work
  2. Remember the *visited* tab order, so back walks the actual path (`Mehr` → `Report` → `Konten` → exit). More faithful
     to "back undoes what I did", but users lose track of how deep they are
  3. A `Navigator` per tab, so each tab owns its stack. The real fix for nested navigation — and a visible behaviour
     change: pushed screens would live inside the tab and the nav bar would stay on screen, where today a push covers it
- Does the app opt into **predictive back** (`android:enableOnBackInvokedCallback` in the manifest)? Without it, Android 14+
  shows no preview animation, and a `PopScope` that blocks the pop behaves differently from one that allows it
- Should leaving the app ever ask? A confirm-to-exit dialog is a common answer and an equally common annoyance
- What about a pushed screen that has unsaved input (booking form, quick-create dialog)? Whatever is decided here must not
  make it easier to discard typing by accident

## Acceptance Criteria
_Not refined yet — the questions above come first._

## Affected Tests
- A widget test can drive back at shell level: pump `AppShell`, select a tab, invoke the pop and assert the selected index
  rather than the process state. Whether the app actually exits is the platform's business, not something a test asserts
- The existing shell test around `IndexedStack` state retention must stay green

## Fixtures Needed
No.

## Token Usage
_Filled after Done._
