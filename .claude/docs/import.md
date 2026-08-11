# Import (Transaction domain)

PDF statement parsing layer. `lib/features/transaction/import/`.

## PdfParser Interface (`pdf/pdf_parser.dart`)

| Property/Method | Type | Notes |
|---|---|---|
| `id` | String | Stable, unique ID; e.g. `dkb-giro-v1` |
| `displayName` | String | Human-readable name shown in UI |
| `canParse(bytes)` | Future<double> | Returns confidence 0.0–1.0; out-of-range values are clamped, NaN/throw/timeout means skipped |
| `parse(bytes)` | Future<ParseResult> | Extracts structured data from PDF bytes |

## DTOs

### ParsedTransactionCandidate (`pdf/parse_result.dart`)

| Field | Type | Notes |
|---|---|---|
| `bookingDate` | DateTime | Buchungstag; required |
| `valueDate` | DateTime? | Wertstellung (optional; not yet mapped to entity) |
| `amountCents` | int | Signed: negative = expense, positive = income |
| `description` | String | Required |
| `counterparty` | String? | Optional |
| `raw` | Map<String, String> | Parser-specific debug data; defaults to `{}` |

### ParseResult (`pdf/parse_result.dart`)

| Field | Type | Notes |
|---|---|---|
| `transactions` | List<ParsedTransactionCandidate> | Parsed rows from PDF |
| `statementBalanceCents` | int? | Optional: statement's end balance for sanity check |
| `warnings` | List<String> | Unparseable regions or ambiguous rows; defaults to `[]` |

## PdfParserRegistry (`pdf/pdf_parser_registry.dart`)

Holds available parsers and ranks them per document.

| Method | Behavior |
|---|---|
| `register(parser)` | Add a parser. Throws `ArgumentError` if id already registered (duplicate check) |
| `all` | Returns unmodifiable list of all registered parsers |
| `rank(bytes)` | Calls `canParse` on all parsers **in parallel**; returns list of `({PdfParser parser, double confidence})` tuples sorted DESC by confidence. Parsers that throw or exceed `canParseTimeout` (default 5s) are **skipped**, not fatal |

Typedef: `PdfParserRanking = ({PdfParser parser, double confidence})`

## Provider

- `pdfParserRegistryProvider` (`pdf/pdf_parser_providers.dart`) — registers `const IngGiroParser()`, yielding exactly one parser: `ing-giro-v1`

## Conversion

`candidateToTransaction(candidate, {required accountUuid})` (`candidate_conversion.dart`)
- Maps `ParsedTransactionCandidate` → unsaved `Transaction`
- Leaves `uuid`, `createdAt`, `updatedAt` unset (filled by `TransactionRepository.save`)
- Drops `valueDate` — entity has no Wertstellung field
- Sets `accountUuid` to caller-provided value

## IngGiroParser (`pdf/ing_giro_parser.dart`)

| Property | Value |
|---|---|
| `id` | `ing-giro-v1` |
| `displayName` | `ING Girokonto` |
| `canParse(bytes)` | Returns `0.95` if first page text contains both `ING-DiBa AG` AND `Girokonto`, else `0.0`; never throws on corrupt/non-PDF bytes |
| `parse(bytes)` | Converts PDF to positioned words via Syncfusion, delegates table logic to `parseIngStatement` |

## PositionedWord & parseIngStatement (`pdf/ing_giro_layout.dart`)

| Item | Details |
|---|---|
| `PositionedWord` | Immutable: `{page: int, left: double, top: double, text: String}` |
| `parseIngStatement` | Pure function: `List<PositionedWord> → ParseResult`; word text is trimmed on ingestion |

**Row Grammar:**
- Date + Amount → new booking (`bookingDate`, `amountCents`)
- Bare date → Valuta (`valueDate`) for current booking
- Description column text → continuation; `Mandat:`/`Referenz:` split into `raw`
- Non-date in date column → skip (page furniture)

**Column Behavior:** Derived from each page's header row (Buchung, second Buchung, Betrag); carried forward if a page's header does not extract. `Neuer Saldo` supplies `statementBalanceCents` and terminates the table.

## ImportFlow (`domain/import_flow_controller.dart`)

- `ImportRow`: immutable, `fromCandidate`, `toCandidate`, `copyWith`, `included: bool`
- `ImportSummary`: `imported`, `skipped`, `warnings` counts
- `ImportFlowController extends AutoDisposeNotifier`: methods `loadDocument`, `selectParser`, `parseDocument`, `toggleRow`, `editRow`, `persist`; raw bytes in private `_bytes` field, dropped on dispose
- `importFlowProvider`: `NotifierProvider.autoDispose<ImportFlowController, ImportFlowState>`
- **Persistence:** `persist` routes included rows through `candidateToTransaction` → `TransactionRepository.save` (single place to build `Transaction`)

## UI Flow

`PdfImportScreen(accountUuid:)` (`presentation/pdf_import_screen.dart`)
- Entry: PDF icon in `TransactionListScreen` app bar, left of the account-edit action
- Steps:
  1. Pick PDF via `file_selector` dialog (single .pdf file)
  2. Registry ranks parsers; show list with confidence %
  3. User picks parser (first ranked is pre-selected)
  4. Click "Auslesen" → per-row list with include/exclude checkbox
  5. Per-row edit dialog: expense/income toggle, amount, description, counterparty, date
  6. Target-account dropdown (pre-filled with entry account), import button (shows included count)
  7. Persist → summary screen: `N importiert / M übersprungen / K Hinweise`
- Persistence: wired via `TransactionRepository.save`

## Still Missing (owned by ticket 009+)

- Duplicate detection: document-level hash before parsing, re-import modal, `ImportedSource` rows, per-row warnings, intra-batch cross-hashing
- Password-protected PDFs (out of scope)
- Batch import (out of scope; one file at a time)
- `valueDate` has nowhere to go — `Transaction` entity lacks Wertstellung field

## Testing

- **Layout logic:** synthetic word coordinates (`test/features/transaction/import/pdf/ing_giro_layout_test.dart`); no PDF required
- **Parser detection:** `canParse` behaviour and shipped registry contents (`test/features/transaction/import/pdf/ing_giro_can_parse_test.dart`)
- **Controller:** ranking, parse, toggle, edit, persist, summary (`test/features/transaction/import/domain/import_flow_controller_test.dart`)
- **Widget:** UI wiring without database (`test/features/transaction/import/import_flow_widget_test.dart`)
- **Reconciliation harness:** env-gated on `ING_PDF` (`test/tool/ing_geometry_dump_test.dart`); dumps geometry and verifies sum against `Neuer Saldo − Alter Saldo`
- **Fixtures:** none; no PDF committed; real statements never enter the repo
