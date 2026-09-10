---
title: Architecture Decisions
date: 2026-09-10
description: One record per architectural decision, oldest first, so a settled question is not reopened.
---

# Architecture Decisions

One file per decision, `NNNN-<english-kebab-slug>.md`, numbered oldest first. Check this table
before asking "why was X done this way" — the answer is likely already here.

Records migrated from the former `decisions.md` carry a gap marker instead of an Evidence section:
that table was kept without `file:line` citations, and inventing them afterwards would be guessing.
Every **new** ADR cites the code that implements it, and a citation is re-verified before it is
acted on, because line numbers rot.

| ADR | Date | Decision |
|-----|------|----------|
| [0001](0001-flutter-as-app-framework.md) | 2026-08-10 | Use Flutter as the app framework |
| [0002](0002-isar-as-local-persistence.md) | 2026-08-10 | Use Isar as local persistence, local-first |
| [0003](0003-supabase-as-future-sync-layer.md) | 2026-08-10 | Reserve Supabase as the future sync layer, prep only |
| [0004](0004-google-ml-kit-for-ocr.md) | 2026-08-10 | Use Google ML Kit for OCR |
| [0005](0005-linear-regression-for-forecast.md) | 2026-08-10 | Use linear regression for the forecast |
| [0006](0006-plugin-system-for-pdf-parsers.md) | 2026-08-10 | Use a plug-in system for PDF parsers |
| [0007](0007-fractal-categorization.md) | 2026-08-10 | Use fractal categorization, line-item overrides parent |
| [0008](0008-duplicate-detection-via-hash.md) | 2026-08-10 | Detect duplicates via a hash of amount, date and description |
| [0009](0009-riverpod-as-state-management.md) | 2026-08-10 | Use Riverpod as state management |
| [0010](0010-android-only-target.md) | 2026-08-10 | Target Android only, no iOS/Web/Desktop |
| [0011](0011-feature-first-folder-layout.md) | 2026-08-10 | Use a feature-first folder layout |
| [0012](0012-flutter-lints-as-linter.md) | 2026-08-10 | Use flutter_lints (default) as the linter |
| [0013](0013-package-and-app-name.md) | 2026-08-10 | Set package to de.lorkaps_apps.budget_view, app name to BudgetView |
| [0014](0014-no-db-encryption.md) | 2026-08-10 | No DB encryption, rely on Android FBE plus app sandbox |
| [0015](0015-isar-community-3-3-2.md) | 2026-08-10 | Use isar_community 3.3.2, not 4.x |
| [0016](0016-dev-nuke-rebuild-prod-manual-migration.md) | 2026-08-10 | Dev: nuke and rebuild on schema change; Prod: manual migration from v1.0 |
| [0017](0017-sync-stub-interface-and-change-queue.md) | 2026-08-10 | Sync stub as interface plus local change queue (op-log) |
| [0018](0018-change-queue-entry-shape.md) | 2026-08-10 | Change-queue entry shape: {op, entity_type, entity_id, payload_json, ts} |
| [0019](0019-entity-ids-as-uuid-v4.md) | 2026-08-10 | Entity IDs are client-generated UUID v4 |
| [0020](0020-repository-layer-enqueue-hook.md) | 2026-08-10 | Repository-layer hook, every mutation calls adapter.enqueue() |
| [0021](0021-money-as-int64-cents.md) | 2026-08-10 | Represent money amounts as int64 cents |
| [0022](0022-currency-eur-only-for-mvp.md) | 2026-08-10 | Currency is EUR only for the MVP, no field |
| [0023](0023-soft-delete-for-account.md) | 2026-08-10 | Soft-delete for Account via an archived flag |
| [0024](0024-category-tree-free-roots-sign-as-direction.md) | 2026-08-10 | Category tree has free roots, the sign of the amount is the direction |
| [0025](0025-category-delete-blocked-with-children-or-transactions.md) | 2026-08-10 | Category delete is blocked when children or transactions exist |
| [0026](0026-category-name-unique-per-parent.md) | 2026-08-10 | Category name is unique per parent, not globally |
| [0027](0027-transaction-soft-delete.md) | 2026-08-10 | Transaction uses soft-delete via a deleted flag |
| [0028](0028-dedupe-hash-composition.md) | 2026-08-10 | Dedupe hash is SHA-256 over amountCents, bookingDate and normalized counterparty |
| [0029](0029-raw-documents-not-persisted.md) | 2026-08-10 | Raw documents (PDFs and receipt photos) are not persisted |
| [0030](0030-importedsource-content-hash.md) | 2026-08-10 | ImportedSource entity: SHA-256 content hash plus metadata per import |
| [0031](0031-parser-choice-via-confidence-ranking.md) | 2026-08-11 | Choose a PDF parser via confidence ranking, user may override |
| [0032](0032-broken-parser-skipped-not-fatal.md) | 2026-08-11 | A parser that throws or times out in canParse is skipped, not fatal |
| [0033](0033-file-selector-as-file-picker.md) | 2026-08-11 | Use file_selector (not file_picker) as the file picker |
| [0034](0034-syncfusion-flutter-pdf-for-extraction.md) | 2026-08-11 | Use syncfusion_flutter_pdf for PDF text extraction |
| [0035](0035-no-fixture-pdfs-balance-verification.md) | 2026-08-11 | No fixture PDFs, verify parsers via balance reconciliation against real statements |
| [0036](0036-ing-column-boundaries-from-header-row.md) | 2026-08-11 | Derive ING column boundaries from each page's header row, not hard-coded |
| [0037](0037-row-grammar-without-booking-type-whitelist.md) | 2026-08-11 | Row grammar has no whitelist of booking types |
| [0038](0038-dedupe-stays-in-ticket-009.md) | 2026-08-11 | Dedupe stays entirely in ticket 009, ticket 008 only imports |
| [0039](0039-not-set-is-null-everywhere.md) | 2026-08-12 | "Not set" is null everywhere, no empty-string sentinel |
| [0040](0040-category-required-in-form-not-field.md) | 2026-08-12 | Category requirement sits in the form, not the field |
| [0041](0041-dedupehash-recomputed-on-every-save.md) | 2026-08-12 | dedupeHash is recomputed on every save, not only when empty |
| [0042](0042-importedsource-delete-is-hard-delete.md) | 2026-08-12 | ImportedSource.delete really deletes, no soft-delete |
| [0043](0043-intra-batch-duplicates-mark-both-copies.md) | 2026-08-12 | Intra-batch duplicates mark both copies |
| [0044](0044-shared-import-artifacts-own-domain.md) | 2026-08-12 | Shared import artifacts live in their own Import domain, format-specific code stays put |
| [0045](0045-cross-cutting-services-as-interface-plus-local-impl.md) | 2026-08-12 | Cross-cutting services are an interface plus a Local implementation |
| [0046](0046-line-items-as-section-in-transaction-form.md) | 2026-08-13 | Line items sit as a section in TransactionFormScreen, no separate detail screen |
| [0047](0047-quantity-mismatch-is-sheet-warning-not-repo-rejection.md) | 2026-08-13 | quantity × unitPrice ≠ amount is a warning in the sheet, not a repo rejection |
| [0048](0048-new-collection-without-schema-bump.md) | 2026-08-13 | New collection without bumping kDbSchemaVersion |
| [0049](0049-category-resolver-lives-in-drilldown.md) | 2026-08-13 | Category resolver lives in Drilldown, not the Category path from ticket 012 |
| [0050](0050-reconcile-called-from-ui-paths-not-repo-hook.md) | 2026-08-13 | reconcile() is called from UI paths, not a hook in TransactionRepository.save |
| [0051](0051-restposten-protection-via-save-guard-and-test.md) | 2026-08-13 | Restposten protection via a save() guard plus a test, not the compiler |
| [0052](0052-restposten-row-excluded-from-drag-and-swipe.md) | 2026-08-13 | Restposten row is excluded from drag and swipe, rather than rejected on attempt |
| [0053](0053-tagginglearnservice-called-from-ui-not-observer.md) | 2026-08-13 | TaggingLearnService.learnFrom is called from UI paths, not an observer on TransactionRepository.save |
| [0054](0054-taggingrule-delete-is-hard-delete.md) | 2026-08-13 | TaggingRule.delete really deletes, no soft-delete |
| [0055](0055-categoryautosuggested-introduced-early.md) | 2026-08-13 | Transaction.categoryAutoSuggested introduced already in 013, before 014 sets it true |
| [0056](0056-rule-management-ui-cut-to-ticket-025.md) | 2026-08-13 | Rule-management UI from ticket 013 is cut into its own ticket 025 |
| [0057](0057-parent-soft-delete-does-not-cascade-to-line-items.md) | 2026-08-13 | Parent soft-delete does not cascade to line items |
| [0058](0058-ocr-and-parser-contract-in-016-implementation-later.md) | 2026-08-17 | OCR and parser contract are defined in 016, implementation follows in 017/018 |
| [0059](0059-scan-entry-as-button-no-detail-screen.md) | 2026-08-17 | Scan entry point is a button in LineItemsSection, no detail screen |
| [0060](0060-no-provenance-field-for-scanned-line-items.md) | 2026-08-17 | No provenance field for "line items from scans", the planned counter is dropped |
| [0061](0061-doc-hash-over-raw-bytes-before-downscale.md) | 2026-08-17 | Document hash is taken over the raw bytes, downscale happens after |
| [0062](0062-photo-bytes-outside-riverpod-state.md) | 2026-08-17 | Photo bytes live outside Riverpod state, autoDispose plus listenManual for the flow |
| [0063](0063-no-android-permission-for-scan.md) | 2026-08-17 | No Android permission for the scan |
| [0064](0064-restposten-reconcile-in-016-confirm.md) | 2026-08-17 | Restposten reconcile already runs at 016's confirm step, not first in 018 |
| [0065](0065-ocrresult-carries-layout-not-flat-strings.md) | 2026-08-17 | OcrResult carries layout (blocks, lines, Rect), not just flat strings |
| [0066](0066-no-ocrempty-exception.md) | 2026-08-17 | No OcrEmptyException; an empty result flows through, only OcrEngineException aborts |
| [0067](0067-ocr-via-temp-file-not-nv21-conversion.md) | 2026-08-17 | OCR runs over a dedicated, immediately deleted temp file instead of NV21 conversion in Dart |
| [0068](0068-ml-kit-recognizer-long-lived-per-provider.md) | 2026-08-17 | ML Kit recognizer is long-lived per provider, released via ref.onDispose |
| [0069](0069-no-automated-verification-of-real-text-recognition.md) | 2026-08-17 | No automated verification of real text recognition; umlauts are checked on-device |
| [0070](0070-scan-candidates-carry-unsigned-magnitudes.md) | 2026-08-17 | Scan candidates carry unsigned magnitudes, the flow sets the sign at persist time |
| [0071](0071-row-grouping-across-block-boundaries-by-y-overlap.md) | 2026-08-17 | Row grouping crosses block boundaries via y-overlap, price is the rightmost money token |
| [0072](0072-unit-price-only-when-division-lands-on-the-cent.md) | 2026-08-17 | Unit price is set only when amount / quantity lands on the cent, otherwise null |
| [0073](0073-unit-stays-in-description-quantity-is-consumed.md) | 2026-08-17 | Unit of measure stays in the description text, quantity is consumed from it |
| [0074](0074-unsavable-candidates-skipped-at-confirm.md) | 2026-08-17 | Unsavable candidates are skipped at confirm, not presented to the repository |
| [0075](0075-review-is-own-screen-in-modal-chain.md) | 2026-08-17 | Review is its own screen inside the modal chain, not another dialog |
| [0076](0076-no-and-noreceiptlineitemparser-deleted.md) | 2026-08-17 | NoOcrService and NoReceiptLineItemParser are deleted, not kept as a fallback |
| [0077](0077-report-entry-as-appshell-navigationbar-indexedstack.md) | 2026-08-18 | Report entry is an AppShell with NavigationBar + IndexedStack, not an icon in the accounts AppBar |
| [0078](0078-direction-filter-decides-at-the-transaction.md) | 2026-08-18 | Direction filter (expenses/income) decides at the transaction, not the line item |
| [0079](0079-sums-stay-signed-internally-magnitude-at-row-edge.md) | 2026-08-18 | Sums stay signed internally, magnitudes only appear at the row edge (abs()) |
| [0080](0080-line-items-loaded-via-anyof-bulk-query.md) | 2026-08-18 | A month's line items load via an anyOf bulk query (findByTransactions), not N × findByTransaction |
| [0081](0081-dangling-categoryuuid-counts-as-uncategorized.md) | 2026-08-18 | A categoryUuid pointing to no existing category counts as "Ohne Kategorie" |
| [0082](0082-drilldown-shows-parent-direct-amounts-as-own-row.md) | 2026-08-18 | Drilldown shows the parent's own amounts as its own row, "X (direkt)", including a donut segment |
| [0083](0083-german-month-names-hardcoded-no-intl-locale.md) | 2026-08-18 | German month names are hard-coded in date_format.dart, no intl locale dataset |
| [0084](0084-monthly-series-as-computeseries-on-existing-service.md) | 2026-08-18 | Monthly series is computeSeries() on the existing report service, not N × compute() and not an extracted unit helper |
| [0085](0085-two-entries-into-forecast-tab-and-deep-link.md) | 2026-08-18 | Two entry points into the forecast, shell tab and deep-link from the report row |
| [0086](0086-deep-link-via-long-press-not-third-trailing-button.md) | 2026-08-18 | Deep-link via long-press on the report row, not a third trailing button |
| [0087](0087-forecast-values-below-zero-clamped-to-zero.md) | 2026-08-18 | Forecast values below 0 are clamped to 0 |
| [0088](0088-r2-is-zero-for-variance-free-series.md) | 2026-08-18 | r2 = 0 for a variance-free series, not 1.0 and not NaN |
| [0089](0089-windowmonths-null-means-whole-history.md) | 2026-08-18 | windowMonths = null means the whole history, no -1 sentinel as the ticket suggested |
| [0090](0090-monthlyreportpoint-carries-year-and-month.md) | 2026-08-18 | MonthlyReportPoint carries year + month alongside the report, instead of on MonthlyCategoryReport |
| [0091](0091-bottom-nav-tab-earned-by-usage-frequency.md) | 2026-08-18 | A bottom-nav tab is earned by usage frequency; rare surfaces move behind Mehr / MenuScreen |
| [0092](0092-alternative-from-suggestion-sheet-counts-as-override.md) | 2026-08-19 | An alternative picked from the suggestion sheet counts as an override, not an acceptance (categoryAutoSuggested = false) |
| [0093](0093-suggestion-on-field-blur-not-per-keystroke.md) | 2026-08-19 | Category suggestion fires on leaving the payee field, not per keystroke |
| [0094](0094-archived-and-orphaned-categories-excluded-from-suggestions.md) | 2026-08-19 | Archived and orphaned categories fall out of suggestions |
| [0095](0095-rowsuggestions-on-state-categorysuggested-on-row.md) | 2026-08-19 | rowSuggestions is a map on ImportFlowState (next to rowMatches), categorySuggested lives on ImportRow |
| [0096](0096-item-grouping-via-normalizeformatching-no-fuzzy-merge.md) | 2026-08-19 | Item grouping uses normalizeForMatching, no fuzzy merge of OCR variants |
| [0097](0097-long-press-line-item-opens-price-history.md) | 2026-08-19 | Long-press on a line item opens price history — a pure navigation edge, Drilldown → Analytics |
| [0098](0098-item-providers-autodispose-report-forecast-not.md) | 2026-08-19 | The two item providers are autoDispose, the report and forecast providers are not |
| [0099](0099-price-chart-has-real-time-axis-not-anchored-at-zero.md) | 2026-08-19 | Price chart has a real time axis (days since first purchase) and does not anchor at 0 |
| [0100](0100-no-empty-key-guard-in-trend-service.md) | 2026-08-19 | No empty-key guard in the trend service |
| [0101](0101-png-rasterization-in-repo-via-svg-to-png-script.md) | 2026-08-20 | PNG rasterization is in-repo via tool/svg_to_png.py + make icon-png, instead of manual user export |
| [0102](0102-one-teal-for-both-light-and-dark-no-color-dark.md) | 2026-08-20 | One teal (#009688) for both light and dark, no color_dark |
| [0103](0103-adaptive-framing-lives-in-svg-generator-inset-zero.md) | 2026-08-20 | Adaptive framing lives in the SVG, generator inset = 0 |
| [0104](0104-real-settings-screen-behind-mehr-tile.md) | 2026-08-20 | A real settings screen sits behind a Mehr tile, instead of hanging data lists directly on the Mehr tab |
| [0105](0105-tagging-rules-only-curated-not-hand-created.md) | 2026-08-20 | Tagging rules can only be curated, not created by hand |
| [0106](0106-quick-create-in-picker-asks-only-the-name.md) | 2026-08-20 | Quick-create in the picker only asks for the name; the parent is fixed by pressing + |
| [0107](0107-report-month-selection-stays-material-datepicker.md) | 2026-08-20 | Month selection in the report stays the Material DatePicker with a day grid, no dedicated month dialog |
| [0108](0108-deskew-image-before-ocr.md) | 2026-08-21 | Deskew the image before OCR, instead of compensating angle only in row grouping |
| [0109](0109-rotation-fills-new-corners-with-paper-white.md) | 2026-08-21 | Rotation fills new corners with paper white |
| [0110](0110-printed-total-is-read-but-never-imported.md) | 2026-08-21 | The printed total is read, but never imported |
| [0111](0111-rows-without-money-token-discarded.md) | 2026-08-21 | Rows without a money token are discarded, instead of offered as unparsed |
| [0112](0112-category-reachable-from-dialog-and-row-chip.md) | 2026-08-21 | Category is reachable from both the import edit dialog and the row chip |
| [0113](0113-user-marks-transfers-no-automatic-pairing.md) | 2026-08-21 | The user marks transfers manually; no automatic pairing, no counterparty rule |
| [0114](0114-transactionkind-enum-instead-of-bool-istransfer.md) | 2026-08-21 | TransactionKind enum instead of bool isTransfer |
| [0115](0115-generic-pdf-parser-validates-against-grand-total.md) | 2026-08-21 | Generic PDF parser validates itself against the grand total, not sender vocabulary |
| [0116](0116-nothing-may-cost-more-than-the-grand-total.md) | 2026-08-21 | Nothing may cost more than the grand total |
| [0117](0117-credits-subtracted-from-total-not-deleted-as-rows.md) | 2026-08-21 | Credits are subtracted from the total, not deleted as line items |
| [0118](0118-scan-flow-renamed-photo-scan-to-receipt-scan.md) | 2026-08-21 | Scan flow renamed from photo_scan to receipt_scan, ReceiptPhotoScanFlowController to ReceiptScanFlowController |
| [0119](0119-transfers-stay-in-account-balance-despite-report-exclusion.md) | 2026-08-21 | Transfers stay in the account balance, even though they fall out of the report |
| [0120](0120-name-hit-in-picker-search-pulls-whole-subtree.md) | 2026-08-24 | A name hit in picker search pulls the whole subtree, non-matching ancestors kept as path |
| [0121](0121-picker-search-is-case-insensitive-substring.md) | 2026-08-24 | Picker search is case-insensitive substring, not normalizeForMatching |
| [0122](0122-trade-republic-money-market-sweep-not-imported.md) | 2026-08-24 | Trade Republic money-market sweep (TRANSAKTIONSÜBERSICHT) is not imported |
| [0123](0123-row-direction-from-running-saldo-column.md) | 2026-08-24 | Row direction comes from the running SALDO column, not which amount column holds the number |
| [0124](0124-trade-republic-isin-is-the-counterparty.md) | 2026-08-24 | For Trade Republic, ISIN is the counterparty, not the instrument name |
| [0125](0125-failed-tr-reconciliation-refuses-whole-statement.md) | 2026-08-24 | Failed Trade Republic reconciliation refuses the whole statement, while the ING parser only warns |
| [0126](0126-positionedword-and-band-grouping-in-own-file.md) | 2026-08-24 | PositionedWord and band grouping live in their own file; bands order by visual line before x |
| [0127](0127-device-local-ui-preferences-in-shared-preferences.md) | 2026-08-24 | Device-local UI preferences live in shared_preferences, not in Isar and not in AppMeta |
| [0128](0128-shell-level-popscope-for-back-navigation.md) | 2026-08-24 | Back at a secondary tab selects Konten, back at Konten leaves the app — PopScope at shell level |
| [0129](0129-only-ing-giro-and-tr-cash-are-importable.md) | 2026-08-24 | Only the ING Girokonto and TR Cashkonto are importable; ING Extrakonten are maintained by hand |
| [0130](0130-two-receipt-parsers-share-only-layout-independent-rules.md) | 2026-08-24 | The two receipt parsers share only layout-independent rules, no convergence |
| [0131](0131-plausibility-limit-vs-printed-total-plus-credits.md) | 2026-08-24 | Plausibility limit compares against printed total plus credits, not total alone |
| [0132](0132-superscript-cents-composed.md) | 2026-08-24 | Superscript cents are composed; the row tolerance stays as tuned by 035 |
| [0133](0133-skip-vocabulary-word-boundary-rule.md) | 2026-08-24 | Skip vocabulary matches at word start or end; `zwischensumme` explicitly excluded |
| [0134](0134-transaction-merchant-alongside-counterparty.md) | 2026-08-24 | `Transaction.merchant` alongside `counterparty`; tagging keys on merchant first |
| [0135](0135-merchant-read-from-both-occurrences.md) | 2026-08-24 | Merchant read from both occurrences in payment reference; fewer spaces wins |
| [0136](0136-pdfx-as-pdf-renderer.md) | 2026-08-24 | `pdfx` as PDF renderer, not `pdfrx` or `pdf_render` |
| [0137](0137-rendered-scan-pages-stacked-into-one-ocrresult.md) | 2026-08-24 | Scanned pages are stacked into one `OcrResult` and parsed once, not per page |
| [0138](0138-discarded-rows-as-collapsed-diagnosis.md) | 2026-08-24 | Discarded rows return as collapsed diagnosis in the review screen, not a debug dump |
| [0139](0139-lowest-row-with-money-token-decides-price.md) | 2026-08-24 | OCR path: lowest row with a money token decides the price, rightmost token wins |
| [0140](0140-transferpairservice-in-domain-not-repo-hook.md) | 2026-09-07 | Transfer pairing lives in `TransferPairService`, called from UI, not a repo hook |
| [0141](0141-counterpartuuid-written-link-not-lookup-time-matching.md) | 2026-09-07 | Transfer pair is a written `counterpartUuid` link, not read-time matching |
| [0142](0142-price-anchors-row-median-price-gap.md) | 2026-09-08 | OCR row grouping anchors on price; reach is the median gap between prices |
| [0143](0143-superscript-cents-composition-removed.md) | 2026-09-08 | Superscript-cent composition is removed — replaces the 2026-08-24 entry (0132) |
| [0144](0144-report-screen-modus-monat-jahr.md) | 2026-09-08 | Yearly result is a report-screen mode (`Monat`/`Jahr`), not a new surface |
| [0145](0145-computeresultseries-calls-computeseries-twice.md) | 2026-09-08 | `computeResultSeries` calls `computeSeries` twice, once per direction |
| [0146](0146-result-is-one-signed-number-plus-color.md) | 2026-09-08 | The result shows its own sign plus red/green, an exception to the row-edge magnitude rule |
| [0147](0147-skip-vocabulary-word-boundary-six-chars-ocr-only.md) | 2026-09-08 | OCR skip vocabulary tolerates one edit step for words ≥6 chars; PDF parser stays exact |
| [0148](0148-card-acquirers-recognized-via-name-list.md) | 2026-09-10 | Card acquirers recognized via a name list, not payment-reference shape |
| [0149](0149-merchant-segment-cut-at-refr.md) | 2026-09-10 | Merchant segment is cut at `Refr`, without proof the reference changes per transaction |
