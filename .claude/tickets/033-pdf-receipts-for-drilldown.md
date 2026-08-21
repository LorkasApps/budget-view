# PDF receipts as a drilldown source

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Drilldown |
| **Domain** | Drilldown |
| **Blocked By** | 035 (its total-as-checksum comparison and deskew are reused here) |
| **Status** | Done |

## Description
The receipt flow accepts a camera capture or a gallery image. But a growing share of receipts never exists on paper:
Amazon and similar send a PDF invoice. Those are line-item sources too, and today there is no way in — the drilldown
stays empty for exactly the purchases that arrive with the best structured data.

A digital PDF is the easier case, not the harder one: it carries a text layer, so `syncfusion_flutter_pdf` (already a
dependency, used by the statement import) can extract text directly and **OCR is not involved at all**. What has to be
answered is what happens to that text afterwards.

## Why this is not just "add a third source button"
The parser from ticket 018 was written against OCR output of German supermarket receipts: rightmost money token per line,
a prefix skip list for the totals block, tolerance for blocks ML Kit split apart. An invoice has a different shape — item
tables, quantity and unit-price columns, descriptions wrapping over several lines — and the layout changes per sender. The
picker entry is an afternoon; the parsing is the ticket.

The documents will come from many senders, so this is not solved by one sender-specific parser. It is solved by a generic
row-and-amount reader that can tell whether it succeeded — see the resolution below.

## Resolved during refinement
- **Generic, not sender-specific.** The user already knows the documents will come from many different senders, so an
  Amazon parser is of little use. The parser groups words into rows and reads the amount belonging to each row. A PDF is a
  far better starting point for that than a photo: the text layer carries exact word coordinates, so there is no skew and
  no recognition noise — the row grouping that fails on crooked receipts (035) is trustworthy here
- **The printed total is the acceptance signal.** Rows are formed, the rightmost money token per row is its amount, the
  document's total is located, and the parsed positions are checked against it. Matching confirms the set; not matching
  means the rows arrive as `ambiguous` in the review screen instead of as truth. It is the only signal independent of the
  layout, and 035 builds the comparison anyway. A parser that can check itself is allowed to be generic. If no total is
  found, the validation simply does not happen and everything stays `ambiguous`
- **Source model** → `ImportedSourceKind` gains a third value appended at the end (`receiptPdf`). Isar stores `@enumerated`
  by index, so appending leaves existing rows untouched: no `kDbSchemaVersion` bump, no migration, and the import history
  can name the row correctly. Accepted cost: the enum keeps mixing format and origin path, now with three values across two
  dimensions
- **Scanned PDFs** → rendering them was decided during refinement and **split out into ticket 044** during implementation.
  The reason is the evidence, not the effort: the text-layer path is covered by unit tests and reconciles on a real document,
  so it can ship. The renderer needs a new native dependency, a release APK and a scanned PDF to be verified at all — and
  ticket 034 showed today what an unverified native dependency costs. Until 044 lands, a scanned PDF is refused with a
  message pointing at the camera
- **Pages** → all of them, read as one sequence. The total sits on the last page of a multi-page invoice, and without it the
  validation the parser relies on cannot happen. Accepted cost: for scans, every page is rendered and recognised
- **Attachment** → always started from a booking, exactly like the photo path. The assignment is a user decision and never
  guessed, and the Restposten closing the gap against the booking amount doubles as a second plausibility check. Accepted
  cost: an invoice whose booking has not been imported yet cannot be filed
- **Test data** → real PDFs stay out of the repo. Same shape as the ING harness: an env-gated test reads a document from a
  path handed in through an environment variable, and the user drops one or two real invoices in a temp dir for the design
  round. Deterministic parser rules are covered by unit tests over synthetic words with coordinates

## Layout findings from a real receipt (Picnic, printed from Gmail via Chrome)
Read with `tool/pdf_text_dump.py`, which exists because the agent cannot run the Dart equivalent.

| Finding | Consequence for the parser |
|---------|---------------------------|
| A price arrives as **three fragments** — integer, `.`, decimals — at nearly equal x with y differing by up to 9 units | Fragments must be joined into words before any money token is recognisable |
| An item is a **block, not a line**: quantity far left, an image, the name (one or two lines), a unit like `250g` / `1,25L` / `2 Stück`, and the price right. The name sits *below* the price | Cluster by y with a tolerance around 20 units — the gap between items is ~70, so clustering separates them, while a small tolerance tears one item into three rows |
| A row may carry **two prices**: a struck-through original in black and the real one in red **below** it | The rule is not "rightmost token" alone but the **bottom-most** price of the block. Position decides, so no colour information is needed |
| `Gesamtbetrag` is the total | Caught by the existing `gesamt` prefix |
| `Zwischensumme`, `Mwst 19% (…)` and `Du sparst` are not items | The first two are already skipped; `du sparst` is new |
| Deposit: only the **`Pfand` total** is a position; its breakdown (`Tüten`, `Flaschen`) is not | Skip the breakdown, keep the total |
| `Eingereichtes Pfand` is a **credit** the printed total already accounts for | It cannot be a position (a `LineItem` amount has no sign), but dropping it silently would break the checksum forever: it is **subtracted** in the comparison instead. On the sample this makes the positions reconcile to the cent — 101,08 minus 1,47 equals the printed 99,61 |
| Page furniture — a mail header, a register number, four Gmail URLs — reassembles into amounts of up to 15 million euros | **Nothing may cost more than the printed total.** One bound removed all of it, without naming a single sender's vocabulary |
| Syncfusion splits words at ligatures and kerning pairs (`Röstkaf` + `fee`) with a gap of 0, while a real space is over 3 | Glue below an eighth of the block tolerance. It matters beyond looks: price trends group by normalised description |
| The email's legal and address block carries no amount | Dropped by the rule from 035: no money token, no candidate |

## Constraint: one document, one booking
The premise stays: a document belongs to exactly one booking, chosen by the user. A document holding several transactions is
the wrong input, not a case to split automatically.

The first sample was believed to hold three transactions — an order, a re-order and a deposit return. Measuring it settled
that: the positions reconcile to the printed total on the cent, so the **document** is one receipt. The three transactions
are three debits on the bank statement, which is a different question and belongs to whoever attaches the document to a
booking.

## Acceptance Criteria
- [x] The receipt source picker offers a PDF entry; `file_selector` returns a single `.pdf`
- [x] The flow is only reachable from an open booking, and the resulting positions are written to that booking
- [x] Text-layer path: words with coordinates come from `syncfusion_flutter_pdf`; fragments are joined into words, words
      into blocks by vertical clustering, and the **bottom-most** money token of a block is its amount — which is what makes
      a struck-through price lose to the real one below it
- [x] The quantity column left of the description is read as `quantity` where present, and a unit like `250g` stays in the
      description, since `LineItem` has no unit field (ticket 023)
- [x] All pages are read as one sequence
- [x] The document total is located and compared against the sum of the parsed positions. **Amended during
      implementation**: a mismatch shows the review banner from 035 with both figures instead of marking every row
      `ambiguous`. Marking them would clear `includeInSave` on all of them, so a 30-position receipt would need 30 fresh
      ticks — and changing the selection silences the very banner that says whether it adds up now
- [x] The total row itself never becomes a position
- [x] Scanned path — **split into ticket 044**. A PDF without a usable text layer fails with a message pointing at the
      camera; `ReceiptPdfReader.read()` returning null is the seam that ticket picks up
- [x] The renderer dependency — **moved to ticket 044** together with its KGP and release-APK requirements. Nothing in this
      ticket added a native dependency, which is why it could close on the evidence it has
- [x] `ImportedSourceKind` gains `receiptPdf` appended at the end; `kDbSchemaVersion` is untouched and existing rows keep
      their meaning
- [x] The import history shows such a row with the document's filename and a label that says PDF receipt, not `Foto`
- [x] Re-picking the same document triggers the doc-hash warning, with wording that fits a receipt rather than a statement
- [x] Candidates land in the existing scan review screen; confirming writes line-items and one `ImportedSource` row, and the
      Restposten closes the remaining gap
- [x] Unit tests over synthetic words with coordinates: row grouping, rightmost-amount rule, total validation match and
      mismatch, multi-page sequencing
- [x] An env-gated harness parses a real document from a path in an environment variable, like `ing_geometry_dump_test.dart`
      does for statements; no document is committed
- [x] `make check` green. Device and real-document checks live in 036

## Out of Scope (proposed, to confirm)
- Fetching invoices from a mailbox or a shop account — the user picks a file, nothing goes online
- Storing the PDF itself (project-wide decision: documents are never persisted)

## Affected Tests
- New parser suite over synthetic words with coordinates — a digital PDF is deterministic input, so unlike the OCR path this
  is genuinely unit-testable
- New env-gated harness for a real document, mirroring `test/tool/ing_geometry_dump_test.dart`
- The scan review and `ImportedSource` suites gain the new kind

## Fixtures Needed
Ask during refinement.

### Refinement Tokens (estimate)
- Input: ~24k tokens
- Output: ~4k tokens

### Implementation Tokens (estimate)
- Input: ~150k tokens
- Output: ~16k tokens

## Outcome
467 tests pass. The generic parser reconciles a real Picnic receipt to the cent: 30 positions summing to 101,08 against a
printed 99,61 plus a 1,47 deposit credit.

What the real document changed about the plan:

| Belief going in | What measuring showed |
|-----------------|-----------------------|
| A price is a money token in a row | It is three words on three baselines — large integer, raised cents, a period — and must be reassembled |
| Rightmost token per row is the amount | The **bottom-most** band of a block is, which is how a struck-through price loses to the real one |
| Noise rows need skip vocabulary | One bound does it: nothing may cost more than the printed total. That removed a mail header, a register number and four URLs |
| A credit row can be dropped | Then the checksum can never reconcile. It is subtracted instead, because a `LineItem` amount carries no sign |
| The sample held three transactions | It holds one receipt; the three debits are a statement question |

Two traps worth remembering are now in `errors.md`: an appended `@enumerated` value reads back as the enum's **first** value
until `make gen` runs, and Dart written through a shell heredoc loses its `\!` characters.
