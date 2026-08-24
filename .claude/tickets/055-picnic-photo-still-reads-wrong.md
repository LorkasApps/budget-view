# A photographed Picnic receipt still reads almost nothing correctly

| Field | Value |
|-------|-------|
| **Type** | Bug |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | None |
| **Severity** | High |
| **Status** | Draft |

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

## Open questions for refinement
- **How does the dump leave the app?** A dev-only entry that writes the `OcrResult` as JSON next to the scan flow, a share
  intent, or a line in the existing collapsed diagnostic that can be copied? It must not become a permanent feature that
  writes recognised receipt text to disk — the whole area is built on not persisting documents
- Is the dump worth keeping afterwards as the standing instrument for the next OCR defect, or is it scaffolding that goes when
  this ticket closes?
- Does the failure depend on the capture path — camera versus gallery, and does the deskew step (035) change the picture?
- Is it the same defect as 045 (rows dropped) or a different one (rows present, values wrong)? The review screen's numbers
  answer this before any code is read
- Does the printed total read correctly? If it does, the checksum can name the size of the error; if not, nothing bounds it

## Acceptance Criteria
_Not refined yet — the dump comes first, and the pattern is derived from it, not guessed._

## Affected Tests
- A fixture built from the real dump, in `heuristic_receipt_line_item_parser_test.dart`, is the regression test this ticket
  owes. The synthetic cases of 045 stay, but they clearly did not describe reality and must not be trusted as the only proof

## Fixtures Needed
No committed image. Real coordinates, transcribed from the dump into an inline fixture.

## Token Usage
_Filled after Done._
