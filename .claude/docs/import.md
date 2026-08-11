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

- `pdfParserRegistryProvider` (`pdf/pdf_parser_providers.dart`) — starts empty; concrete parsers register themselves in later tickets

## Conversion

`candidateToTransaction(candidate, {required accountUuid})` (`candidate_conversion.dart`)
- Maps `ParsedTransactionCandidate` → unsaved `Transaction`
- Leaves `uuid`, `createdAt`, `updatedAt` unset (filled by `TransactionRepository.save`)
- Drops `valueDate` — entity has no Wertstellung field
- Sets `accountUuid` to caller-provided value

## UI Flow

`PdfImportScreen(accountUuid:)` (`presentation/pdf_import_screen.dart`)
- Entry: PDF icon in `TransactionListScreen` app bar, left of the account-edit action
- Steps:
  1. Pick PDF via `file_selector` dialog (single .pdf file)
  2. Registry ranks parsers; show list with confidence %
  3. User picks parser (first ranked is pre-selected)
  4. Click "Auslesen" → `parser.parse(bytes)` → preview list of converted rows + warnings
- Persistence: **NOT wired** (later ticket)

## Not Yet Wired

- No concrete parser registered (stub only)
- No persistence of parsed rows (UI preview only, no save button)
- No duplicate detection (ticket 009)
- No password-protected PDF support (out of scope)
- Batch import out of scope (one file at a time)
