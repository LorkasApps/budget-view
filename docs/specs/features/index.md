---
title: Features
date: 2026-09-10
description: Feature and TechDebt specs with status, epic, domain and blocking relationships.
---

# Features

The column names below are a contract: `.claude/helper/ticket_status_count.py` and its siblings key
off this header row and read the filename out of the markdown link in the `File` cell. Extra columns
are fine, renamed ones break the helpers.

`Blocked By` lists specs that must be `Done` before this one may move to `In Progress`. Reaching
`Ready` with open blockers is allowed — acceptance criteria can be tightened while a blocker is
still open.

| File | Type | Epic | Domain | Status | Blocked By | Summary |
|------|------|------|--------|--------|------------|---------|
| [001-flutter-project-init.md](001-flutter-project-init.md) | Feature | Setup | Infra | Done | None | Bootstrap Flutter project structure |
| [002-isar-setup-base-schema.md](002-isar-setup-base-schema.md) | Feature | Setup | Infra | Done | 001 | Isar 3.3.2 + base schema + DB init (no encryption) |
| [003-supabase-sync-adapter-stub.md](003-supabase-sync-adapter-stub.md) | Feature | Setup | Infra | Done | 002 | Supabase sync adapter interface (stub only) |
| [004-account-entity-crud.md](004-account-entity-crud.md) | Feature | Accounts | Account | Done | 002, 003 | Multi-account entity + CRUD |
| [005-account-balance-display.md](005-account-balance-display.md) | Feature | Accounts | Account | Done | 004 | Per-account balance display |
| [006-manual-transaction-entry.md](006-manual-transaction-entry.md) | Feature | Import | Transaction | Done | 004, 005 | Manual transaction entry form |
| [007-pdf-parser-plugin-interface.md](007-pdf-parser-plugin-interface.md) | Feature | Import | Transaction | Done | 006 | Abstract PDF parser plug-in contract |
| [008-first-concrete-pdf-parser.md](008-first-concrete-pdf-parser.md) | Feature | Import | Transaction | Done | 007 | First concrete PDF parser (ING Giro, ephemeral) |
| [009-duplicate-detection-hash.md](009-duplicate-detection-hash.md) | Feature | Import | Import | Done | 006, 008 | Duplicate detection (tx-level + doc-level SHA-256) |
| [010-category-tree-entity-crud.md](010-category-tree-entity-crud.md) | Feature | Categories | Category | Done | 002, 003 | Category tree entity + CRUD |
| [011-category-assignment.md](011-category-assignment.md) | Feature | Categories | Category | Done | 010, 006 | Assign one category per transaction |
| [012-fractal-category-inheritance.md](012-fractal-category-inheritance.md) | Feature | Categories | Drilldown | Done | 011, 015 | Line-item category overrides parent transaction |
| [013-tagging-rule-storage.md](013-tagging-rule-storage.md) | Feature | Auto-Tagging | Tagging | Done | 011 | Store learned rules from user assignments (management UI split into 025) |
| [014-auto-suggest-on-import.md](014-auto-suggest-on-import.md) | Feature | Auto-Tagging | Tagging | Done | 013 | Suggest category on new imports |
| [015-line-item-entity.md](015-line-item-entity.md) | Feature | Drilldown | Drilldown | Done | 006 | Line-item entity (child of transaction) |
| [016-kassenbon-photo-capture.md](016-kassenbon-photo-capture.md) | Feature | Drilldown | Drilldown | Done | 015, 009 | Camera / gallery capture flow (ephemeral, no persistence) |
| [017-ocr-mlkit.md](017-ocr-mlkit.md) | Feature | Drilldown | Drilldown | Done | 016 | OCR via Google ML Kit (in-memory only) |
| [018-ocr-to-line-items.md](018-ocr-to-line-items.md) | Feature | Drilldown | Drilldown | Done | 017 | Parse OCR text into line-items (heuristic + user review) |
| [019-sum-validation.md](019-sum-validation.md) | Feature | Drilldown | Drilldown | Done | 015 | Auto-managed Restposten (invariant sum) |
| [020-monthly-category-report.md](020-monthly-category-report.md) | Feature | Analytics | Analytics | Done | 006, 011, 012, 015 | Monthly report: donut + tree-aware table |
| [021-forecast-linear-regression.md](021-forecast-linear-regression.md) | Feature | Analytics | Analytics | Done | 020 | Forecast (LR, user-picked window + horizon) |
| [022-item-price-trends.md](022-item-price-trends.md) | Feature | Analytics | Analytics | Done | 015, 018, 029 | Item price trends (auto-group by normalized description) |
| [023-unit-price-normalization.md](023-unit-price-normalization.md) | Feature | Analytics | Analytics | Draft (post-V1) | 015, 018, 022 | Weight-based unit-price for variable-weight items (€/kg, €/l) |
| [024-import-history-screen.md](024-import-history-screen.md) | Feature | Import | Import | Done | 009 | ImportedSource list + delete, split out of 009 (needs a Settings surface) |
| [025-tagging-rule-management.md](025-tagging-rule-management.md) | Feature | Auto-Tagging | Tagging | Done | 013 | Rule list + edit/delete + stale handling, split out of 013 (shares the Settings surface with 024) |
| [026-quick-create-category-in-picker.md](026-quick-create-category-in-picker.md) | Feature | Categories | Category | Done | None | Quick-create a category from inside pickCategory (name + prefilled parent, defaults for the rest) |
| [027-app-icon-and-branding.md](027-app-icon-and-branding.md) | Feature | Setup | Infra | Done | None | Money-bag launcher icon (adaptive + monochrome) and launch screen via flutter_native_splash |
| [028-milestone-1-verification-pass.md](028-milestone-1-verification-pass.md) | TechDebt | None | Infra | Done | 024, 025, 026 | One device + visual pass over all of milestone 1 — collects every check `make check` cannot make (native halves, rendering, gestures); carries 022 + 014 visual checks |
| [029-menu-tab-for-rare-surfaces.md](029-menu-tab-for-rare-surfaces.md) | Feature | None | Infra | Done | None | Bottom nav stays at Konten \| Report \| Mehr; rare surfaces (Prognose, later 022/024/025) live behind a menu screen |
| [031-theme-mode-setting.md](031-theme-mode-setting.md) | Feature | Setup | Infra | Done | None | Theme mode row in Settings: Dunkel / Hell / Systemvorgabe (default), dark scheme from the same teal seed |
| [032-transfers-between-own-accounts.md](032-transfers-between-own-accounts.md) | Feature | None | Transaction | Done | 037 | Transfers between own accounts count as expense + income and inflate the report; model has no notion of them |
| [033-pdf-receipts-for-drilldown.md](033-pdf-receipts-for-drilldown.md) | Feature | Drilldown | Drilldown | Done | 035 | PDF receipts as a line-item source: generic row parser validated against the printed total, scanned PDFs rendered through OCR |
| [036-v2-receipt-verification-checklist.md](036-v2-receipt-verification-checklist.md) | TechDebt | None | Drilldown | Draft | 034, 035, 033, 037 | Device checks for the receipt pipeline after its fixes, plus PDF receipts and the tagging-suggestion loop |
| [037-clear-category-in-import-preview.md](037-clear-category-in-import-preview.md) | Feature | Import | Transaction | Done | None | Reach the row category from the import edit dialog; chip already allows change and clear |
| [038-category-picker-search.md](038-category-picker-search.md) | Feature | Categories | Category | Done | None | Search in the category picker: a name hit pulls its whole subtree along, at any depth |
| [040-trade-republic-import.md](040-trade-republic-import.md) | Feature | Import | Transaction | Done | 032 | Trade Republic cash/Tagesgeld parser; securities lines are plain expenses/income, no holdings model |
| [042-transfer-counter-leg-on-target-account.md](042-transfer-counter-leg-on-target-account.md) | Feature | None | Transaction | Done | 032 | Name the target account of a transfer and book the counter-leg there; the pair lives in TransferPairService, the import collision is 048 |
| [044-render-scanned-pdf-receipts.md](044-render-scanned-pdf-receipts.md) | Feature | Drilldown | Drilldown | Done | 043 | Render a scanned PDF's pages through the OCR path; APK size verified, the four release-build device checks waived unrun on 2026-09-07 |
| [046-backup-local-and-google-drive.md](046-backup-local-and-google-drive.md) | Feature | None | Infra | Draft | None | Backup to a local file and to Google Drive; first network access, and an unencrypted DB leaving the sandbox |
| [047-merchant-behind-a-collective-payer.md](047-merchant-behind-a-collective-payer.md) | Feature | Auto-Tagging | Transaction | Done | None | PayPal hides the real merchant in the purpose text; needs a `merchant` field, pattern to be read off real lines first |
| [048-import-meets-a-booked-counter-leg.md](048-import-meets-a-booked-counter-leg.md) | Feature | Import | Transaction | Ready | 042 | Split from 042: an import meets the mirror booking; dedupe cannot catch it, and only ING Giro ↔ TR Cash can collide |
| [050-more-collective-payers-adyen-nexi.md](050-more-collective-payers-adyen-nexi.md) | Feature | Auto-Tagging | Transaction | Done | None | Adyen and Nexi hide the shop too, but in the card-terminal shape; Nexi still unseen, so dump before pattern |
| [051-one-subcategory-level-only.md](051-one-subcategory-level-only.md) | Feature | Categories | Category | Ready | None | Cap the tree at roots plus one child level; parent picker shrinks to the roots, and depth-only helpers can go |
| [052-net-result-per-month-and-year.md](052-net-result-per-month-and-year.md) | Feature | Analytics | Analytics | In Progress | None | Signed `Ergebnis` line plus a `Jahr` mode with twelve tappable month rows; two `computeSeries` calls, no second aggregation. Gate green (614), device check on the four-column width open |
| [053-search-and-category-filter-in-the-account-list.md](053-search-and-category-filter-in-the-account-list.md) | Feature | None | Transaction | Done | None | Word search plus a category filter in the per-account list; overlaps 049, follows the 038 search semantics |
| [054-search-in-the-category-tree-screen.md](054-search-in-the-category-tree-screen.md) | Feature | Categories | Category | Done | None | Search in the tree screen, deferred by 038; reuses filterCategoryTree, drag handles hide while a query is active |
| [056-category-suggestion-per-line-item.md](056-category-suggestion-per-line-item.md) | Feature | Auto-Tagging | Tagging | Ready | 055 | Suggest a category per scanned position, keyed on the article description; needs matchField in the lookup, value hinges on 055 |
| [057-picnic-receipt-sections-per-reorder.md](057-picnic-receipt-sections-per-reorder.md) | Feature | Drilldown | Drilldown | Ready | None | Reframed: the user crops per day, so a fragment has no printed total and the booking is the only figure to judge against |
| [059-month-filter-in-the-account-list.md](059-month-filter-in-the-account-list.md) | Feature | None | Transaction | Draft | None | One month at a time in the account list with stepping; same control row as 053, and the boundary a per-month query could use |
| [062-picnic-pdf-sections-per-added-order.md](062-picnic-pdf-sections-per-added-order.md) | Feature | Drilldown | Drilldown | Draft | 061 | Split the PDF at `Hinzugefügt am` + `Bestellnr` (heading height 12 vs median 8); both sections share one date, so the order number is the key and the summed subtotal is a hint, not a checksum |
| [063-migrate-docs-to-mdbunker-hierarchy.md](063-migrate-docs-to-mdbunker-hierarchy.md) | TechDebt | None | Infra | Done | None | Move `.claude/docs` + `.claude/tickets` into the MDBunker `docs/` hierarchy: 13 reference pages, 149 ADRs translated to English, 16 troubleshooting pages, 62 specs; seven commits, helpers and `CLAUDE.md` last |
