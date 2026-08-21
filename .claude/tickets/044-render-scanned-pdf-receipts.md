# Read scanned PDF receipts by rendering their pages

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | None (033 shipped the PDF source and the text-layer path) |
| **Status** | Draft |

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

## Open questions for refinement
- **Which package?** `pdfx`, `pdf_render`, or something else. Selection criteria worth applying: no Kotlin-Gradle-Plugin
  warning (the one 030 had to chase), a maintained release within the last months, and APK size — the universal build is
  already at 98,7 MB
- **What does it cost per page?** Rendering plus OCR plus deskew, on a phone, for a multi-page document. Is there a page
  limit, or a progress indication so the flow does not look frozen?
- **At what resolution?** Too low loses small print, too high wastes seconds. The photo path downscales to 2000 px longest
  edge, which is a starting point rather than an answer
- **Does the checksum still work?** OCR of a rendered page produces the OCR parser's output, which — per ticket 043 — lacks
  the credit subtraction and the plausibility bound the PDF parser has. Whichever of 043 and this ticket lands second
  inherits the other's shape
- **Where does the branch live?** `SyncfusionReceiptPdfReader` returns null today; either it renders and recognises itself
  (then the reader is no longer a pure text-layer reader), or the controller routes to the OCR path with rendered bytes
  (then `_read()` grows a third case)
- Does a hybrid document exist in practice — a text layer on page one, a scan on page two — and what should happen then?

## Acceptance Criteria
_Not refined yet — the questions above come first._

## Out of Scope (proposed, to confirm)
- Improving OCR accuracy itself; the rendered page is treated like a photo
- Anything about the text-layer path, which is done

## Affected Tests
- The renderer goes behind an interface so flow tests keep working without a PDF, mirroring `ReceiptPdfReader`
- Verification of the real thing is a device round on a **release** APK, not `make run` — that is the lesson of 034 and it
  belongs in this ticket's ACs

## Fixtures Needed
No committed documents. A scanned PDF is handed over out of band, like the receipts before it.

## Token Usage
_Filled after Done._
