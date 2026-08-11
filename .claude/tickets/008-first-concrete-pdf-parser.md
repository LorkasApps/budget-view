# First concrete PDF parser (ING Giro)

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Import |
| **Domain** | Transaction |
| **Blocked By** | 007 |
| **Status** | In Progress |

## Description
First concrete `PdfParser` implementation targeting **ING Girokonto** statements. Uses `syncfusion_flutter_pdf` (community edition) for text extraction. Registers with `PdfParserRegistry` on app init. Completes the import flow end-to-end: pick file → auto-detect parser → preview / edit rows → target account → persist.

Builds on ticket 007, which already provides the `PdfParser` contract, the registry with confidence ranking, `PdfImportScreen` (file pick via `file_selector`, parser ranking + override, read-only preview) and `candidateToTransaction`. This ticket fills the registry and turns the preview into a real import.

**PDF bytes are ephemeral** — held in memory only during the import flow, dropped on flow exit. No file storage.

### Scope boundary vs ticket 009
All duplicate detection stays in 009: document-level hash check before parsing, the re-import modal, `ImportedSource` rows, per-row duplicate warnings, intra-batch cross-hashing and the preview header counts. 009 hooks into the flow this ticket builds. Cut line: **008 imports, 009 warns.**

## Parser

| Field | Value |
|-------|-------|
| `id` | `ing-giro-v1` |
| `displayName` | `ING Girokonto` |
| `canParse` | `0.95` if PDF text contains ING-Header markers (e.g. `ING-DiBa AG`, `Girokonto`); `0.0` otherwise |
| `parse` | Extracts page text via `PdfDocument.pages[i].text`, matches transaction rows via regex, returns `ParseResult` |

## Acceptance Criteria
- [ ] `syncfusion_flutter_pdf` added to `pubspec.yaml` (text extraction)
- [ ] `pdf` added as `dev_dependency` (fixture authoring only, never shipped)
- [ ] `IngGiroParser` implements `PdfParser` — `lib/features/transaction/import/pdf/ing_giro_parser.dart`, id `ing-giro-v1`
- [ ] `canParse()` returns `0.95` when the extracted text carries the ING header markers (`ING-DiBa AG` and `Girokonto`), `0.0` otherwise
- [ ] `canParse()` never throws on a non-PDF / corrupt byte stream — returns `0.0`
- [ ] `parse()` extracts per row: `bookingDate`, `valueDate`, `amountCents` (signed EUR), `description`, `counterparty`; keeps the raw source line in `raw`
- [ ] `parse()` fills `statementBalanceCents` from the statement footer when present
- [ ] `parse()` collects unparseable rows into `warnings` instead of throwing
- [ ] Parser registers itself into `pdfParserRegistryProvider` at app init (bootstrap in `main.dart`); registry then yields exactly `ing-giro-v1`
- [ ] `PdfImportScreen` (from 007) extended into a real import:
  - [ ] per-row include/exclude toggle, all rows included by default
  - [ ] per-row editable fields: `bookingDate`, `amountCents`, `description`, `counterparty`
  - [ ] target-account dropdown, pre-filled with the account the flow was opened from
  - [ ] confirm → persist included rows via `TransactionRepository.save`
  - [ ] summary after persist: `N importiert / M übersprungen / K Hinweise`
- [ ] Flow logic is testable without the native picker — parsed bytes are injectable, so widget tests never call `file_selector`
- [ ] PDF bytes are never written to disk — `Uint8List` lives only in screen / controller state and is dropped on flow exit
- [ ] Cancel at any step → nothing persisted

## Layout Findings (verified against a real July 2026 statement, 10 pages)
Non-obvious facts about the ING text layer. Each of these broke a first attempt.

| Fact | Consequence |
|------|-------------|
| Three columns at identical x on every page: Buchung/Valuta ≈70.8, Verwendungszweck ≈141.6, Betrag ≈493.8 (right-aligned, xMin varies with width) | Columns are derived from each page's header row, not hard-coded |
| Header reads `Buchung Buchung / Verwendungszweck Betrag EUR` — the extractor **drops parentheses** | Matching `Betrag (EUR)` fails silently; match the bare word `Betrag` |
| `TextWord.text` arrives padded with surrounding spaces | Untrimmed text breaks `indexOf('Neuer')` and doubles spaces in every join |
| `TextLine` is **not** band-equivalent: Valuta (y=571.8) and its continuation (y=572.1) are separate lines | Own y-banding (3pt tolerance) is required; rows sit ~12pt apart |
| Vertical document marker `34GKKA…` is one word **per character** at x≈29 | Words left of the date column must be discarded |
| Footnote markers sit right of the amount as their own word (`-0,48` at x=529, `1` at x=552) | Filtered by the amount pattern, no special case needed |
| Appendix page (11 of a 10-page statement) has no table header | Columns carry forward from the previous page; a page with no known columns is skipped silently |
| Copy-paste from a PDF viewer flattens the table and appends amounts as a page-end block | That ordering artifact does **not** exist in the real text layer — never calibrate on viewer copy-paste |

**Reconciliation check:** sum of all 77 bookings = `-46736` cents = `Neuer Saldo 2.927,04 − Alter Saldo 3.394,40`. This is the acceptance signal for parser correctness; no synthetic fixture can match it.

## Out of Scope (owned by ticket 009)
- Document-level hash check before parsing + re-import modal
- `ImportedSource` row creation
- Per-row duplicate warning icons, intra-batch cross-hashing
- Preview header `N new / M possible duplicates`

## Fixtures

- [ ] `tool/gen_ing_fixtures.dart` — Dart script generating synthetic ING-style PDFs (uses `pdf` dev-dependency for authoring)
- [ ] Committed under `test/fixtures/ing/`:
  - `simple.pdf` — 5 clean transactions, single page
  - `complex.pdf` — multi-page, mixed rows (income + expenses), Umlaute, valueDate ≠ bookingDate
  - `malformed.pdf` — one broken row → tests warning collection

## Affected Tests
- `test/features/transaction/import/pdf/ing_giro_parser_test.dart` — parse each fixture; candidate counts, amounts, warnings
- `test/features/transaction/import/pdf/ing_giro_can_parse_test.dart` — match vs non-match confidence
- `test/features/transaction/import/import_flow_widget_test.dart` — injected bytes → detect → preview → exclude one row → edit one row → confirm → persisted transactions match, cancel persists nothing

## Refinement Tokens (estimate)
- Input: ~13k tokens
- Output: ~4k tokens

## Token Usage
_Filled after Done._
