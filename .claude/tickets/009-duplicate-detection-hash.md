# Duplicate detection (transaction + document level)

| Field | Value |
|-------|-------|
| **Type** | Feature |
| **Epic** | Import |
| **Domain** | Import |
| **Blocked By** | 006, 008 |
| **Status** | Done |

## Description
Two-layer defence against duplicate imports:

1. **Document-level** — SHA-256 of the raw file bytes (PDF or receipt photo) checked at the file-picker entry point, **before** parsing. Hash match surfaces a warning; user may override and continue.
2. **Transaction-level** — SHA-256 over `amountCents` + `bookingDate` (date-only) + normalized `counterparty` per candidate row, checked in the import preview. Match flagged per row; user may include anyway.

Raw documents are **not persisted** (per project-wide decision). Only `ImportedSource` metadata rows persist for re-import warnings.

## Where things live
This ticket creates a new `Import` domain for artifacts shared by *every* import
path, and leaves format-specific code where it already is. Ticket 008's ING
parser and PDF flow do **not** move.

| Artifact | Home | Why |
|----------|------|-----|
| `ImportedSource`, `content_hash.dart`, `DuplicateChecker` | `lib/features/import/` | Needed by PDF import (008) and photo scan (016) alike; belongs to neither |
| `dedupe_hash.dart` (`computeDedupeHash(Transaction)`) | `lib/features/transaction/domain/` | Hashes a transaction, so it lives with transactions |
| ING parser, import flow controller, `PdfImportScreen` | `lib/features/transaction/import/` (unchanged) | PDF-specific |

Direction of dependency: `Transaction → Import` and later `Drilldown → Import`.
Never the reverse. Add both edges to `dependencies.md` during implementation.

## Scope boundary vs ticket 016
016 owns the **photo** side end to end — its ACs already call
`duplicateCheckerProvider.findDocumentMatches` and write the `kind=photo`
`ImportedSource` row. This ticket only has to *provide* the checker and the
entity. Cut line: **009 provides, 016 consumes.**

## Entities

### `Transaction` — add field

| Field | Type | Notes |
|-------|------|-------|
| `dedupeHash` | String | Indexed, non-nullable. SHA-256 hex, computed from tx fields |

### `ImportedSource` — new collection

| Field | Type | Notes |
|-------|------|-------|
| `id` | int (auto-inc) | Isar internal |
| `uuid` | String | UUID v4 (from `SyncableEntity`) |
| `kind` | enum | `pdf` \| `photo` |
| `contentHashSha256` | String | Indexed, hex-encoded (64 chars) |
| `filename` | String | Displayable name from picker; may be empty for camera captures |
| `importedAt` | DateTime | Wall-clock at time of persist |
| `transactionsProduced` | int | 0-N transactions this import created |
| `lineItemsProduced` | int | 0-N line-items this import created |
| `note` | String? | Optional, e.g. "User overrode duplicate warning" |
| `createdAt` | DateTime | |
| `updatedAt` | DateTime | |

No uniqueness constraint on `contentHashSha256` — repeated imports of the same file (after warning override) create additional rows; history preserved.

## Hash Rules

**Transaction hash (`dedupeHash`):**
- Input: `amountCents`, `bookingDate` (formatted `YYYY-MM-DD`), `counterparty` normalized (lower → trim → whitespace-collapse). Empty counterparty stays empty.
- Canonical string: `"${amountCents}|${bookingDate}|${counterpartyNorm}"`
- Algorithm: SHA-256 → hex.

**Document hash (`contentHashSha256`):**
- Input: raw file bytes (unmodified).
- Algorithm: SHA-256 → hex.

Same normalization helper serves ticket 009 + 013 (tagging).

## Match Scope
- **Transaction hash:** same `accountUuid` only. Transfers between accounts remain distinct.
- **Document hash:** global. Same file re-picked from anywhere in the phone triggers the warning.

## Match Semantics
Both layers = **suspicion**, not blocker. User decides.

## Acceptance Criteria
- [x] `dedupeHash` added to `Transaction` (indexed, non-nullable)
- [x] `ImportedSource` Isar collection defined in `lib/features/import/data/imported_source.dart`
- [x] `ImportedSourceRepository`: `save`, `findByHash(hash) → List<ImportedSource>` (sorted `importedAt DESC`), `findAll`, `findByUuid`, `delete(uuid)`
- [x] Writes to `ImportedSource` route through `syncAdapter.enqueue(...)`
- [x] `computeDedupeHash(Transaction)` pure helper in `lib/features/transaction/domain/dedupe_hash.dart` — unit-tested, plus `dedupeHashOf(...)` for preview rows that are not entities yet
- [x] `computeContentHash(bytes)` pure helper in `lib/features/import/domain/content_hash.dart` — unit-tested
- [x] `TransactionRepository.save(...)` maintains `dedupeHash` — **recomputed on every write**, not only when empty, so an edited amount or date cannot leave a stale hash
- [x] `DuplicateChecker` in `lib/features/import/domain/` — an **interface** with `LocalDuplicateChecker` as implementation, mirroring `SyncAdapter`:
  - `findTransactionMatches(hash, accountUuid:, {excludeDeleted: true}) → List<Transaction>`
  - `findDocumentMatches(hash) → List<ImportedSource>`
- [x] `duplicateCheckerProvider` (Riverpod) exposes service
- [x] **PDF import (ticket 008 flow):** after file-pick, hash bytes → `findDocumentMatches` → modal naming the earlier import date and count, with Fortfahren / Abbrechen; cancelling leaves the flow so the bytes are dropped
- [x] On confirm import: create one `ImportedSource` row with `kind=pdf`, hash, filename, counts — plus a `note` when the document had been seen before
- [x] **Manual entry (ticket 006 form):** on submit, `findTransactionMatches` → modal lists existing matches with Trotzdem speichern / Abbrechen. An edited booking is filtered out of its own matches
- [x] **PDF-import preview list (ticket 008 UI):** suspicious rows carry a marker that opens the matching bookings
- [x] **Intra-batch check:** rows are cross-hashed within one document; **both** copies are flagged, since the user decides which to keep
- [x] Preview-list header shows `N neu / M mögliche Duplikate`
- [x] No back-fill needed: there is no app installation, so no pre-009 rows exist

## Deviations from the original spec
| Spec | Built | Why |
|------|-------|-----|
| `save` populates `dedupeHash` "if empty" | Recomputed on every write | Editing an amount, date or counterparty would otherwise leave a hash describing the old booking, and the check would compare against something that no longer exists |
| `DuplicateChecker` as a plain service | Interface + `LocalDuplicateChecker` | Mirrors `SyncAdapter`; without the seam the database-free widget tests would have to reach into Isar, which hangs in `testWidgets` |
| `persist({required accountUuid})` | `persist()`, target account in controller state | Duplicate matching is account-scoped, so switching the destination must re-run the check — the account is flow state, not an argument of the final action |
| "internal duplicates flagged" | **Both** copies flagged | The second copy is not inherently the wrong one; the user decides which to keep |

## Residual gaps
Two paths are covered only structurally, both because they end in a repository
write and Isar cannot run inside `testWidgets`:
- "Trotzdem speichern" actually persisting after the manual-entry warning
- an edited booking being filtered out of its own match list

Every write-through-UI path in this project now has this shape. Fixing it
properly means a repository interface in the style of `SyncAdapter` and
`DuplicateChecker` — worth its own TechDebt ticket, not this one.

## Out of Scope
- Photo-scan doc-hash integration — ticket 016 owns it and already specifies it
- Import-history screen (list + delete `ImportedSource` rows) — ticket 024, it needs a Settings surface that does not exist yet
- Moving ticket 008's PDF code into the new `Import` domain — format-specific code stays put

## Affected Tests
- `test/features/transaction/domain/dedupe_hash_test.dart`
- `test/features/import/domain/content_hash_test.dart` — deterministic per bytes, differs on 1-byte change
- `test/features/import/domain/duplicate_checker_test.dart` — both `findTransactionMatches` + `findDocumentMatches`
- `test/features/transaction/import/pdf/pdf_dedupe_integration_test.dart` — doc-hash warning + row-level warnings + intra-batch flagging
- `test/features/transaction/presentation/manual_entry_dupe_modal_test.dart` — tx-hash modal appears on hit, absent on miss
- `test/features/import/data/imported_source_repository_test.dart` + sync-integration

## Fixtures Needed
No — reuses ING fixtures from 008 + inline builders.

## Refinement Tokens (estimate)
- Input: ~14k tokens
- Output: ~5k tokens

## Implementation Tokens (estimate)
- Input: ~175k tokens
- Output: ~30k tokens
