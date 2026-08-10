# First concrete PDF parser (ING Giro)

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Import |
| **Domain** | Transaction |
| **Blocked By** | 007 |
| **Status** | Ready |

## Description
First concrete `PdfParser` implementation targeting **ING Girokonto** statements. Uses `syncfusion_flutter_pdf` (community edition) for text extraction. Registers with `PdfParserRegistry` on app init. Completes the import flow end-to-end: pick file → doc-hash-check (integration point for ticket 009) → auto-detect parser → preview → assign account → persist.

**PDF bytes are ephemeral** — held in memory only during the import flow. Discarded once the import completes or is cancelled. No file storage. Only `ImportedSource` metadata (from ticket 009) persists.

Transaction-level duplicate detection (per-row warnings in the preview) is provided by ticket 009 and hooks into this ticket's preview UI.

## Parser

| Field | Value |
|-------|-------|
| `id` | `ing-giro-v1` |
| `displayName` | `ING Girokonto` |
| `canParse` | `0.95` if PDF text contains ING-Header markers (e.g. `ING-DiBa AG`, `Girokonto`); `0.0` otherwise |
| `parse` | Extracts page text via `PdfDocument.pages[i].text`, matches transaction rows via regex, returns `ParseResult` |

## Acceptance Criteria
- [ ] `syncfusion_flutter_pdf` added to `pubspec.yaml`
- [ ] `file_picker` added to `pubspec.yaml`
- [ ] `IngGiroParser` class implements `PdfParser` — `lib/features/transaction/import/pdf/ing_giro_parser.dart`
- [ ] `canParse()` matches ING header markers; high confidence on match, `0.0` otherwise
- [ ] `parse()` extracts per row: `bookingDate`, `valueDate`, `amountCents` (signed EUR), `description`, `counterparty`
- [ ] `parse()` fills `statementBalanceCents` from statement footer when present
- [ ] `parse()` collects unparseable rows into `warnings`
- [ ] Parser registers itself in `pdfParserRegistryProvider` on app init (bootstrapper in `main.dart`)
- [ ] Import UI flow:
  - File-picker screen (via `file_picker`)
  - **Doc-hash check** (ticket 009 integration): hash raw bytes → `duplicateCheckerProvider.findDocumentMatches(hash)` → modal warning if match, user can proceed or cancel
  - Auto-detect result screen: top parser + alternatives + user-override
  - Preview list: each row shows `bookingDate`, `counterparty`, `description`, `amountCents`; toggle include/exclude; editable fields; per-row txn-hash-warning icon (from 009)
  - Account picker (target)
  - Confirm → persist as `Transaction` via `TransactionRepository` + create one `ImportedSource` row with `kind=pdf`, hash, filename, counts (via ticket 009's repository)
- [ ] Import summary screen shows `N imported / M skipped / K warnings`
- [ ] **PDF bytes are not stored anywhere** — `Uint8List` lives only in the flow controller / provider state, cleared on flow exit
- [ ] Cancel at any step → bytes discarded, no `ImportedSource` row written

## Fixtures

- [ ] `tool/gen_ing_fixtures.dart` — Dart script generating synthetic ING-style PDFs (uses `pdf` package for authoring)
- [ ] Committed under `test/fixtures/ing/`:
  - `simple.pdf` — 5 clean transactions, single page
  - `complex.pdf` — multi-page, mixed rows (income + expenses), Umlaute, valueDate ≠ bookingDate
  - `malformed.pdf` — one broken row → tests warning collection

## Affected Tests
- `test/features/transaction/import/pdf/ing_giro_parser_test.dart` — parse each fixture; candidate counts, amounts, warnings
- `test/features/transaction/import/pdf/ing_giro_can_parse_test.dart` — match vs non-match confidence
- `test/features/transaction/import/import_flow_widget_test.dart` — full flow: pick file (mocked) → doc-hash miss → detect → preview → confirm → persistence + `ImportedSource` row
- `test/features/transaction/import/import_flow_dochash_hit_test.dart` — doc-hash match modal appears; proceed writes a second `ImportedSource` row; cancel writes none

## Refinement Tokens (estimate)
- Input: ~13k tokens
- Output: ~4k tokens

## Token Usage
_Filled after Done._
