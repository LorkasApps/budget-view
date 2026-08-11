# PDF parser plug-in interface

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Import |
| **Domain** | Transaction |
| **Blocked By** | 006 |
| **Status** | Done |

## Description
Abstract contract that concrete PDF parsers implement. Parsers receive raw PDF bytes and return a list of transaction candidates plus a confidence score for the auto-detect dispatcher. Framework picks the parser with the highest confidence per PDF; user can override.

## Architecture

```
PdfParser (interface)
  String get id                          // stable, unique, e.g. "dkb-giro-v1"
  String get displayName                 // human-readable
  Future<double> canParse(Uint8List bytes)   // 0.0–1.0 confidence
  Future<ParseResult> parse(Uint8List bytes)

ParsedTransactionCandidate (DTO)
  DateTime bookingDate
  DateTime? valueDate                    // optional (Wertstellung)
  int amountCents                        // signed
  String description
  String? counterparty
  Map<String, String> raw                // parser-specific debug data

ParseResult
  List<ParsedTransactionCandidate> transactions
  int? statementBalanceCents             // optional: statement's own end balance for sanity check
  List<String> warnings                  // unparseable regions, ambiguous rows

PdfParserRegistry
  void register(PdfParser parser)
  List<PdfParser> get all
  Future<List<(PdfParser, double)>> rank(Uint8List bytes)   // sorted DESC by confidence
```

## Acceptance Criteria
- [x] `PdfParser` abstract interface in `lib/features/transaction/import/pdf/pdf_parser.dart`
- [x] `ParsedTransactionCandidate` DTO defined (fields as above, immutable)
- [x] `ParseResult` DTO defined
- [x] `PdfParserRegistry` class + Riverpod provider `pdfParserRegistryProvider`
- [x] Registry starts empty; concrete parsers register themselves in ticket 008 onwards
- [x] `rank(bytes)` invokes `canParse()` on all registered parsers in parallel; returns DESC-sorted list
- [x] Import-flow entry point (skeleton widget or service) exists: pick file → `rank()` → show top parser + list of alternatives → user confirms → `parse()` → hand candidates to conversion step
- [x] Conversion step (skeleton, real persistence in ticket 008): candidate + user-picked `accountUuid` → `Transaction` entity (uuid generated, defaults applied)
- [x] No concrete parser implementation in this ticket — registry stays empty
- [x] Unit test: register a fake parser, verify `rank()` orders correctly
- [x] Unit test: `canParse()` timeout / exception handled gracefully (parser skipped)

## Out of Scope
- Password-protected PDFs (later ticket if needed)
- Batch import (one file at a time)
- Persistence of imported transactions (ticket 008 wires this)
- Duplicate detection (ticket 009)

## Affected Tests
- `test/features/transaction/import/pdf/pdf_parser_registry_test.dart`
- `test/features/transaction/import/pdf/parse_result_test.dart`

## Fixtures Needed
- Fake `PdfParser` implementation for tests (in-file, no separate fixture folder needed)

## Refinement Tokens (estimate)
- Input: ~9k tokens
- Output: ~3k tokens

## Implementation Notes
Two deviations from the architecture sketch above, relevant for ticket 008:
- `rank()` returns named-field records `({PdfParser parser, double confidence})`
  instead of positional `(PdfParser, double)` — avoids `.$1` / `.$2` at call sites.
- `valueDate` is dropped in `candidateToTransaction` — `Transaction` has no
  Wertstellung field. Parsers should still fill it; wiring needs an entity change.

`file_selector ^1.1.0` added as picker (see decisions.md).

## Implementation Tokens (estimate)
- Input: ~90k tokens
- Output: ~14k tokens
