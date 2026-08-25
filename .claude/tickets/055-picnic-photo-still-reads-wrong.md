# A photographed Picnic receipt still reads almost nothing correctly

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | None |
| **Severity** | High |
| **Status** | Ready |

## Description
Tickets 043 and 045 landed and `make check` is green, but a scan taken on the device after them still reads almost nothing
correctly. So the raised-cents reassembly, verified against synthetic coordinates, does not describe what ML Kit actually
returns for this receipt — or something else in the chain dominates the result.

This is the second time the same layout defeats the parser, and the first fix was built on assumed geometry. That is the thing
to change about *how* this one is fixed.

## Why the usual harness cannot help here
The PDF fixes were derived from a real document because `syncfusion_flutter_pdf` runs in the test VM. **ML Kit does not** — it
has no test-VM binding (`decisions.md`, 2026-08-17), which is exactly why no automated verification of real recognition
exists. A photo therefore cannot be pushed through a harness the way `ing_geometry_dump_test.dart` pushes a statement.

What can be done instead, and what this ticket proposes: **export the recognised layout from the app**. One dump of the real
`OcrResult` — blocks, lines, their `Rect`s — turns into a fixture with real coordinates, and from there the parser is testable
offline and deterministically, like every other layout rule in this project.

## Evidence to collect before any fix
- [ ] The photo itself, handed over out of band (never committed — `decisions.md`, 2026-08-10: raw documents are not persisted)
- [ ] The dump of its `OcrResult` from the app
- [ ] What the review screen showed: how many positions, and what `N nicht erkannte Zeilen` contains when expanded
- [ ] Whether the sum warning fired, and with which two figures

## Resolved during refinement
- **The dump is a dev-only entry in the review screen** that writes the whole `OcrResult` — blocks, lines and their `Rect`s —
  as JSON into the app cache and shows the path, to be fetched with `adb pull` or a file app. It **stays**, but only in debug
  builds: at the next OCR surprise nobody should have to build it again.
  Rejected: a share intent (that is the same thing plus a path on which receipt text leaves the app, against the rule that raw
  documents are never kept), and a "copy all" on the existing `N nicht erkannte Zeilen` line — that yields text without
  rectangles, and assuming the geometry is exactly how 045 went wrong
- **The pattern is derived from that dump inside this ticket**, not before it, the way ticket 047 handled its purpose texts

## Acceptance Criteria
- [ ] A debug-only action in the scan review writes the full `OcrResult` as JSON to the app cache and names the file; it is
      absent from a release build
- [ ] The dump of the failing Picnic photo is fetched, and the fixture in `heuristic_receipt_line_item_parser_test.dart` is
      built from its **real** coordinates
- [ ] That fixture reproduces the defect before the fix and passes after it
- [ ] For the real receipt: the positions the review offers match the paper — around 30 rows rather than four summary lines —
      and the printed total is recognised so the checksum can judge them
- [ ] Whatever the cause turns out to be, the finding is written into this ticket, including which of 045's synthetic
      assumptions was wrong
- [ ] The synthetic cases of 045 stay green, or their removal is argued in this ticket rather than done quietly
- [ ] `make check` green

## Device check
- [ ] The same photo, on a release APK, yields the same positions as the fixture predicts

## Affected Tests
- A fixture built from the real dump, in `heuristic_receipt_line_item_parser_test.dart`, is the regression test this ticket
  owes. The synthetic cases of 045 stay, but they clearly did not describe reality and must not be trusted as the only proof

## Fixtures Needed
No committed image. Real coordinates, transcribed from the dump into an inline fixture.

### Refinement Tokens (estimate)
- Input: ~9k tokens
- Output: ~1.5k tokens

### Implementation Tokens (estimate)
_Filled after Done._
