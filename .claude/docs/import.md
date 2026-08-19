# Import

## Shared Import Domain (`lib/features/import/`)

Artifacts shared by every import path (PDF, photo, future formats).

### ImportedSource Entity (`data/imported_source.dart`)

Metadata of one completed import. The document itself is not persisted; this row survives to warn on re-import and supply import history.

| Field | Type | Notes |
|---|---|---|
| `id` | Id | Isar auto-inc, internal |
| `uuid` | String | UUID v4, unique index |
| `kind` | ImportedSourceKind | `pdf` / `photo`, @enumerated |
| `contentHashSha256` | String | Indexed (intentionally **not unique**): same file re-imported after override creates a second row for history |
| `filename` | String | Display name from picker; empty for camera captures |
| `importedAt` | DateTime | Wall-clock at persistence |
| `transactionsProduced` | int | Count from this import |
| `lineItemsProduced` | int | Count from this import (0 for PDF, filled by photo flow) |
| `note` | String? | Optional narrative, e.g. "Erneuter Import trotz Warnung" when file was seen before |
| `createdAt` / `updatedAt` | DateTime | Maintained by repo |

### ImportedSourceRepository (`domain/imported_source_repository.dart`)

| Method | Behavior |
|---|---|
| `save(source)` | Persists new or updated, routes through sync adapter |
| `findByHash(contentHashSha256)` | All imports of this file, sorted `importedAt DESC` (newest first) |
| `findAll` | All imports, sorted `importedAt DESC` |
| `findByUuid(uuid)` | — |
| `delete(uuid)` | **Real delete** (not soft-delete); a row only exists to warn, so an archived-but-still-warning row would be pointless; user can delete to force a re-import |

### DuplicateChecker Interface (`domain/duplicate_checker.dart`)

An interface with `LocalDuplicateChecker` as implementation, mirroring `SyncAdapter`/`LocalSyncAdapter`, so widget tests can stub it.

| Method | Scope | Behavior |
|---|---|---|
| `findTransactionMatches(hash, accountUuid:, excludeDeleted:)` | Account-scoped | Bookings on one account with the same dedupe hash; transfers stay distinct |
| `findDocumentMatches(hash)` | Global | Earlier imports of this exact file (by content hash) |

### Content Hash (`domain/content_hash.dart`)

`computeContentHash(List<int> bytes)` → SHA-256 hex of raw bytes; identifies a re-imported file before parsing.

### Providers (`domain/import_providers.dart`)

- `importedSourceRepositoryProvider`
- `duplicateCheckerProvider` (yields `LocalDuplicateChecker`)

---

## PDF Import (Transaction domain)

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

- `ImportRow`: immutable, `fromCandidate`, `toCandidate`, `copyWith`, `included: bool`,
  `categoryUuid` (null = uncategorized, which imported rows may stay),
  `withCategory(uuid, {suggested})` as the only way to clear it (`copyWith` cannot
  express "back to null"), `categorySuggested` (true while the
  category came from a rule and nobody overrode it; travels into
  `Transaction.categoryAutoSuggested` on persist, which keeps the learn hook from
  reinforcing its own guess), computed `dedupeHash`
- `ImportSummary`: `imported`, `skipped`, `warnings` counts
- `ImportFlowState`: extends prior with `contentHash`, `documentMatches` (re-import
  warning list), `targetAccountUuid`, `rowMatches` (row index → existing bookings on
  target account), `intraBatchDuplicates` (row indexes), `rowSuggestions` (row index →
  `List<CategorySuggestion>`, derived display data sitting next to `rowMatches`);
  derives `documentSeenBefore` (bool), `isSuspicious(index)`, `suspiciousCount`, `newCount`
- `ImportFlowController extends AutoDisposeNotifier`: methods `loadDocument` (hashes
  bytes, checks document matches), `selectParser`, `parseDocument`, `toggleRow`,
  `editRow` (async, re-runs duplicate check), `setRowCategory(index, uuid)`,
  `setCategoryForAll(uuid)` (bulk-assigns every row, included or not — the user is
  categorising the statement, not the selection), `setTargetAccount` (async, re-runs
  check since matching is account-scoped), `persist` (async, no longer takes account
  param; uses state). Private `_applySuggestions()` runs after `parseDocument` and
  after `editRow`: per row it looks up suggestions for the counterparty (memoized per
  counterparty within a run, since a statement repeats payees), records them, and fills
  the category with the top hit unless the row was hand-picked; a row whose counterparty
  matches nothing ends up uncategorized again. `setRowCategory` / `setCategoryForAll`
  clear the suggested flag. Raw bytes in private `_bytes` field, dropped on dispose
- `importFlowProvider`: `NotifierProvider.autoDispose<ImportFlowController, ImportFlowState>`
- **Persistence:** `persist` routes included rows through `candidateToTransaction` →
  `TransactionRepository.save`, then writes one `ImportedSource` row with `kind=pdf`,
  document hash, filename, counts, and `note` when `documentSeenBefore`

## UI Flow

`PdfImportScreen(accountUuid:)` (`presentation/pdf_import_screen.dart`)
- Entry: PDF icon in `TransactionListScreen` app bar, left of the account-edit action
- Steps:
  1. `initState` calls `setTargetAccount(widget.accountUuid)` so duplicate scoping is ready before any bytes arrive
  2. Pick PDF via `file_selector` dialog (single .pdf file)
  3. Hash bytes computed; `findDocumentMatches` runs
  4. If document hash seen before: modal shows "Datei schon importiert am [date] · [count] Buchungen" and earlier import counts; **Fortfahren** / **Abbrechen** (cancel leaves flow, bytes dropped)
  5. Registry ranks parsers; show list with confidence %
  6. User picks parser (first ranked is pre-selected)
  7. Click "Auslesen" → per-row list with include/exclude checkbox. Header shows
     `N neu / M mögliche Duplikate`. Each row: `CategoryChip` (per-row, optional —
     rows may be imported uncategorized), edit button, a `Für alle` button in the
     header (bulk-assigns every row regardless of inclusion status). Suggested row
     shows `Icons.auto_awesome_outlined` + `<hitCount>×` next to the chip; tapping
     it opens `pickSuggestion` (only when more than one suggestion exists) and the
     pick goes through `setRowCategory`, i.e. as an override.
  8. Per-row duplicate marker (copy icon, red) opens modal listing existing bookings; intra-batch duplicates flag **both** copies (user decides which to keep)
  9. Per-row edit dialog: expense/income toggle, amount, description, counterparty, date
  10. Target-account dropdown (pre-filled with entry account), import button (shows included count)
  11. Persist → summary screen: `N importiert / M übersprungen / K Hinweise`
- Persistence: wired via `TransactionRepository.save` + writes `ImportedSource` row

## Still Missing

- Import-history screen (list + delete `ImportedSource` rows) — ticket 024, needs Settings surface
- Password-protected PDFs (out of scope)
- Batch import (out of scope; one file at a time)
- `valueDate` has nowhere to go — `Transaction` entity lacks Wertstellung field

## Testing

- **Layout logic:** synthetic word coordinates (`test/features/transaction/import/pdf/ing_giro_layout_test.dart`); no PDF required
- **Parser detection:** `canParse` behaviour and shipped registry contents (`test/features/transaction/import/pdf/ing_giro_can_parse_test.dart`)
- **Controller:** ranking, parse, toggle, edit, persist, summary (`test/features/transaction/import/domain/import_flow_controller_test.dart`)
- **Widget:** UI wiring without database (`test/features/transaction/import/import_flow_widget_test.dart`)
- **Dedupe:** hash units (`dedupe_hash_test.dart`, `content_hash_test.dart`, `core/text/normalize_test.dart`), `duplicate_checker_test.dart`, `imported_source_repository_test.dart`, and `pdf_dedupe_integration_test.dart` for the flow — re-import, row matches, account scoping, intra-batch, `ImportedSource` counts
- **Suggestions:** `import_preview_suggest_test.dart` (suggestions applied, overrides clear
  provenance, persist flags). For the tagging side, suggest service and the
  learn↔suggest loop are covered under `test/features/tagging/domain/`.
- **Not covered:** every path that writes through the UI — confirming a duplicate warning, and an edited booking filtering itself out. Both end in a repository call, and Isar cannot run inside `testWidgets`
- **Reconciliation harness:** env-gated on `ING_PDF` (`test/tool/ing_geometry_dump_test.dart`); dumps geometry and verifies sum against `Neuer Saldo − Alter Saldo`
- **Fixtures:** none; no PDF committed; real statements never enter the repo
