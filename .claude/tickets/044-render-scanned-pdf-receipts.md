# Read scanned PDF receipts by rendering their pages

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | 043 (the OCR parser must carry the borrowed rules first) |
| **Status** | Done |

## Description
Split out of 033. A PDF that carries a text layer is read directly — no OCR involved — and that path is done. A **scanned**
PDF has no text layer: today it fails with "Dieses PDF enthält keinen Text. Fotografiere den Beleg stattdessen."

This ticket makes that case work by rendering each page to a bitmap and running it through the existing OCR pipeline, which
since 035 also deskews. `ReceiptPdfReader.read()` returning null is already the signal that a document belongs here, so the
seam exists.

## Why it was split off
The text-layer path works, is covered by tests and a real document, and could ship. The renderer cannot ship on the same
evidence: it needs a **new native dependency** (pdfium via `pdfx` or equivalent), and today's ticket 034 is the cautionary
tale — ML Kit behaved differently in the release build than in debug, which cost several rounds and produced a shipped APK
that could not read a receipt at all. Verifying this needs a release APK **and** a scanned PDF, neither of which was
available when 033 closed.

## Resolved during refinement
- **Package** → `pdfx` 2.11.0 (released 2026-08-20). Decisive: on Android it renders through the OS's own
  `android.graphics.pdf.PdfRenderer`, so no pdfium enters the APK — the size criterion is met at a build that already sits
  at 98,7 MB. `pdfrx` 2.4.7 was rejected for bundling pdfium (`pdfium_flutter`, `pdfrx_engine`), `pdf_render` for being two
  years stale (1.4.12, 2024-08-26). Accepted cost: `pdfx` pulls `photo_view`, `web` and `flutter_web_plugins` for a viewer
  we never use. Writing ~30 lines of Kotlin against the same OS API was the honest alternative and was dropped so we do not
  own native code on a path where R8 already bit once (034)
- **Order** → blocked by 043. A rendered page goes through the OCR parser, so landing first would ship a path that warns
  falsely on every deposit return and keeps rows costing more than the receipt. As a bonus the checksum AC here reduces to
  "behaves like the photo path"
- **Resolution** → 2000 px longest edge, the same constant as the photo path, so everything 035 tuned against real receipts
  applies unchanged. That is roughly 170 dpi on A4, which may be tight for small print; the number stays a single constant
  and only moves to 3000 px on a device finding, not on a guess
- **Cost and progress** → no hard page limit. Per-page progress in the existing busy state (`Seite 2 von 4 wird gelesen…`),
  because several seconds of silence reads as a frozen app, plus a confirmation above 10 pages so an accidentally picked
  200-page document cannot block the app for minutes. No cancel button — that would be another state in the machine, and
  the existing back path is already a device check in 039
- **Where the branch lives** → the controller routes; `SyncfusionReceiptPdfReader` stays a pure text-layer reader. Giving it
  rendering and recognition too would pull ML Kit into a class whose tests need none, and the controller already owns the
  decision which pipeline reads a document (`decisions.md`, 2026-08-17: "der Controller *ist* das Artefakt von 016"). The
  renderer sits behind a `ReceiptPdfRenderer` interface, mirroring `ReceiptPdfReader`, so flow tests keep running without a PDF
- **Hybrid documents** → decided per **document**, as today. No evidence hybrids occur here, and per-page routing would
  double the controller's branching for a hypothetical case. The gap is made visible instead: if the document has more pages
  than produced text, the flow warns which pages carried none — same bar as the statement import, never silently half-read

## Acceptance Criteria
- [x] `pdfx` added; the Android path renders through the OS `PdfRenderer`
- [x] The release APK grows by no more than a megabyte (measured before and after, `make release-check`) — **98,7 MB**
      (2026-08-20, recorded in ticket 030) → **95,3 MB** (2026-09-07). Same command, same universal all-ABI
      `app-release.apk`, so the two are comparable: it did not grow, it **shrank by 3,4 MB** while gaining `pdfx`. The size
      criterion behind the renderer choice holds with room to spare — pdfium would have gone the other way.
      Observation, out of scope here like the all-ABI note in 030: the decrease is unexplained. `pdfx` only adds
      (`photo_view`, `web`, `flutter_web_plugins`), so something between those two dates shed more than it cost. Worth
      chasing only if a future size criterion depends on knowing why.
- [x] `ReceiptPdfRenderer` interface with the `pdfx` implementation behind it; every flow test still runs without a real PDF
- [x] A PDF **with** a text layer behaves exactly as today — no rendering, no OCR involved (asserted: the renderer is never
      called)
- [x] A PDF **without** a text layer renders each page at 2000 px longest edge and runs the existing OCR pipeline, deskew
      included, instead of failing with `Dieses PDF enthält keinen Text.`
- [x] The busy state names the page being read (`Seite 2 von 4 wird gelesen…`)
- [x] A document with more than 10 pages asks for confirmation before it is read
- [x] Checksum and credits behave exactly like the photo path — inherited from 043, not reimplemented here
- [x] `make check` green — 513 passed, 0 failed

## Noted instead of built: the hybrid warning
> ~~A document whose pages partly carry text keeps the text-layer path and warns which pages carried none.~~

Deferred deliberately (user decision, 2026-08-24). The reader hands back a parse result without saying which pages carried
words, so the warning needs either a field on the shared `ReceiptParseResult` that the OCR path would never fill, or a second
method on `ReceiptPdfReader`. Against that: the refinement already recorded that no hybrid document is known here, and the
case is not silently wrong about figures — a scanned page contributes no words, so the positions of the text pages stay
correct and still reconcile against their own total. What is missing is a hint, and it gets written when a real hybrid PDF
shows up.

## How it was built
- `ReceiptPdfRenderer` (domain) with `PdfxReceiptPdfRenderer` (data). It opens the document per call rather than holding a
  native handle across awaits, which the flow has no lifecycle for
- The controller routes: `read()` returning null now leads to `_countPages` instead of a failure. Above
  `kPageConfirmThreshold` (10) it stops in a new `manyPagesWarning` phase, mirroring the existing `duplicateWarning` handshake
- Pages are rendered and recognised one by one in a new `rendering` phase carrying `pageCount` / `pagesRead`, then **stacked
  into one `OcrResult`** by `stackOcrPages` and parsed once. Parsing per page would have left a total on the last page unable
  to bound the positions on the first
- The progress dialog is opened from the flow's existing `listenManual` subscription when the phase turns `rendering`, not
  around an await — rendering begins inside the controller call, after the file picker is gone

## Device checks (release APK — the lesson of 034)

**Not run. Waived by the user on 2026-09-07, knowingly and as an exception.** No
scanned PDF was at hand — and a document *with* a text layer proves nothing here,
since it takes the 033 path instead. The boxes stay unchecked on purpose: a tick
for something nobody ran would read as evidence later.

- [ ] A real scanned PDF is read end to end on a **release** build, not on `make run`
- [ ] A multi-page scan: every page contributes positions, and the progress text advances
- [ ] The confirmation above 10 pages appears and both answers behave
- [ ] Note the wall-clock time per page and the APK size delta in the ticket — both are the numbers this decision rests on

What this leaves exposed, so a later bug can be traced here instead of
re-discovered: the section is named after 034 because that is where R8 struck in a
release build and nowhere else, and `pdfx` reaches the OS's own
`android.graphics.pdf.PdfRenderer` — a native path is exactly the kind that passes
every test and fails once minified. The unit tests cover the seam
(`ReceiptPdfRenderer` with a fake), never the real renderer.

Of the two numbers this decision was meant to rest on, one is in: the APK size,
verified above. The wall-clock time per page was never taken, so the throughput
half of the `pdfx` choice is unmeasured. Nothing depends on it today.

## Out of Scope (proposed, to confirm)
- Improving OCR accuracy itself; the rendered page is treated like a photo
- Anything about the text-layer path, which is done

## Affected Tests
- The renderer goes behind an interface so flow tests keep working without a PDF, mirroring `ReceiptPdfReader`
- Verification of the real thing is a device round on a **release** APK, not `make run` — that is the lesson of 034 and it
  belongs in this ticket's ACs

## Fixtures Needed
No committed documents. A scanned PDF is handed over out of band, like the receipts before it.

### Refinement Tokens (estimate)
- Input: ~19k tokens
- Output: ~3k tokens

### Implementation Tokens (estimate)
- Input: ~75k tokens
- Output: ~10k tokens
