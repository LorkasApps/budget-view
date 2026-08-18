# First concrete PDF parser (ING Giro)

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Import |
| **Domain** | Transaction |
| **Blocked By** | 007 |
| **Status** | Done |

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
- [x] `syncfusion_flutter_pdf` added to `pubspec.yaml` (text extraction)
- [x] `IngGiroParser` implements `PdfParser` — `lib/features/transaction/import/pdf/ing_giro_parser.dart`, id `ing-giro-v1`
- [x] `canParse()` returns `0.95` when the extracted text carries the ING header markers (`ING-DiBa AG` and `Girokonto`), `0.0` otherwise
- [x] `canParse()` never throws on a non-PDF / corrupt byte stream — returns `0.0`
- [x] `parse()` extracts per row: `bookingDate`, `valueDate`, `amountCents` (signed EUR), `description`, `counterparty`; keeps type, Mandat and Referenz in `raw`
- [x] `parse()` fills `statementBalanceCents` from the statement's `Neuer Saldo`
- [x] `parse()` collects unparseable rows into `warnings` instead of throwing
- [x] Parser is registered so `pdfParserRegistryProvider` yields exactly `ing-giro-v1`
- [x] `PdfImportScreen` (from 007) extended into a real import:
  - [x] per-row include/exclude toggle, all rows included by default
  - [x] per-row editable fields: `bookingDate`, `amountCents`, `description`, `counterparty`
  - [x] target-account dropdown, pre-filled with the account the flow was opened from
  - [x] confirm → persist included rows via `TransactionRepository.save`
  - [x] summary after persist: `N importiert / M übersprungen / K Hinweise`
- [x] Flow logic is testable without the native picker — parsed bytes are injectable, so widget tests never call `file_selector`
- [x] PDF bytes are never written to disk — `Uint8List` lives only in the controller and is dropped on flow exit
- [x] Cancel at any step → nothing persisted

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

## Deviations from the original spec
| Spec | Built | Why |
|------|-------|-----|
| Fixture PDFs `simple` / `complex` / `malformed` generated by `tool/gen_ing_fixtures.dart`, plus the `pdf` dev-dependency | Dropped; no generated fixtures, `pdf` dependency not kept | A PDF authored by the `pdf` package reproduces none of ING's text-layer quirks (padded words, dropped parentheses, vertical marker, split `TextLine`s), so it would assert a path the real extractor never takes. The layout logic is covered by 10 tests over synthetic word coordinates, and the extraction step by the reconciliation harness against a real statement. |
| Registration bootstrapped in `main.dart` | Registration inside `pdfParserRegistryProvider` | Lets a plain test assert the shipped parser set without booting the widget tree. |
| Preview persisted through a widget test | Widget test is database-free; persistence asserted in `import_flow_controller_test.dart` | Real Isar I/O never completes inside `testWidgets`' fake-async zone — the run hangs instead of failing and `--timeout` does not fire. See `.claude/docs/errors.md`. |

**Residual gap:** the wiring from the import button to `persist` is the one step no automated test covers (controller test calls `persist` directly, widget test stops before it). Carried into **028** (milestone-1 verification pass).

## Out of Scope (owned by ticket 009)
- Document-level hash check before parsing + re-import modal
- `ImportedSource` row creation
- Per-row duplicate warning icons, intra-batch cross-hashing
- Preview header `N new / M possible duplicates`

## Fixtures
None. See Deviations — no statement PDF is committed, and real statements never
enter the repository.

## Affected Tests
- `test/features/transaction/import/pdf/ing_giro_layout_test.dart` — 13 tests over synthetic word coordinates: row grammar, Valuta, thousands separator, footnote marker, vertical marker, page furniture, closing balance, per-page and carried-forward columns, padded word text, warnings
- `test/features/transaction/import/pdf/ing_giro_can_parse_test.dart` — id, non-PDF bytes, empty bytes, shipped registry contents
- `test/features/transaction/import/domain/import_flow_controller_test.dart` — ranking, parse, toggle, edit, persist only included rows, summary, parser failure
- `test/features/transaction/import/import_flow_widget_test.dart` — UI wiring without a database: rows and warnings rendered, parser choice, counts, disabled button, edit dialog apply and cancel
- `test/tool/ing_geometry_dump_test.dart` — env-gated (`ING_PDF`): geometry dump plus the reconciliation check against a real statement

## Refinement Tokens (estimate)
- Input: ~13k tokens
- Output: ~4k tokens

## Implementation Tokens (estimate)
- Input: ~210k tokens
- Output: ~34k tokens
