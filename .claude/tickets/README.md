# Tickets

| File | Type | Epic | Domain | Status | Blocked By | Summary |
|------|------|------|--------|--------|------------|---------|
| 001-flutter-project-init.md | Feature | Setup | Infra | Done | None | Bootstrap Flutter project structure |
| 002-isar-setup-base-schema.md | Feature | Setup | Infra | Done | 001 | Isar 3.3.2 + base schema + DB init (no encryption) |
| 003-supabase-sync-adapter-stub.md | Feature | Setup | Infra | Done | 002 | Supabase sync adapter interface (stub only) |
| 004-account-entity-crud.md | Feature | Accounts | Account | Done | 002, 003 | Multi-account entity + CRUD |
| 005-account-balance-display.md | Feature | Accounts | Account | Done | 004 | Per-account balance display |
| 006-manual-transaction-entry.md | Feature | Import | Transaction | Done | 004, 005 | Manual transaction entry form |
| 007-pdf-parser-plugin-interface.md | Feature | Import | Transaction | Done | 006 | Abstract PDF parser plug-in contract |
| 008-first-concrete-pdf-parser.md | Feature | Import | Transaction | Done | 007 | First concrete PDF parser (ING Giro, ephemeral) |
| 009-duplicate-detection-hash.md | Feature | Import | Import | Done | 006, 008 | Duplicate detection (tx-level + doc-level SHA-256) |
| 010-category-tree-entity-crud.md | Feature | Categories | Category | Done | 002, 003 | Category tree entity + CRUD |
| 011-category-assignment.md | Feature | Categories | Category | Done | 010, 006 | Assign one category per transaction |
| 012-fractal-category-inheritance.md | Feature | Categories | Drilldown | Done | 011, 015 | Line-item category overrides parent transaction |
| 013-tagging-rule-storage.md | Feature | Auto-Tagging | Tagging | Done | 011 | Store learned rules from user assignments (management UI split into 025) |
| 014-auto-suggest-on-import.md | Feature | Auto-Tagging | Tagging | Done | 013 | Suggest category on new imports |
| 015-line-item-entity.md | Feature | Drilldown | Drilldown | Done | 006 | Line-item entity (child of transaction) |
| 016-kassenbon-photo-capture.md | Feature | Drilldown | Drilldown | Done | 015, 009 | Camera / gallery capture flow (ephemeral, no persistence) |
| 017-ocr-mlkit.md | Feature | Drilldown | Drilldown | Done | 016 | OCR via Google ML Kit (in-memory only) |
| 018-ocr-to-line-items.md | Feature | Drilldown | Drilldown | Done | 017 | Parse OCR text into line-items (heuristic + user review) |
| 019-sum-validation.md | Feature | Drilldown | Drilldown | Done | 015 | Auto-managed Restposten (invariant sum) |
| 020-monthly-category-report.md | Feature | Analytics | Analytics | Done | 006, 011, 012, 015 | Monthly report: donut + tree-aware table |
| 021-forecast-linear-regression.md | Feature | Analytics | Analytics | Done | 020 | Forecast (LR, user-picked window + horizon) |
| 022-item-price-trends.md | Feature | Analytics | Analytics | Done | 015, 018, 029 | Item price trends (auto-group by normalized description) |
| 023-unit-price-normalization.md | Feature | Analytics | Analytics | Draft (post-V1) | 015, 018, 022 | Weight-based unit-price for variable-weight items (€/kg, €/l) |
| 024-import-history-screen.md | Feature | Import | Import | Done | 009 | ImportedSource list + delete, split out of 009 (needs a Settings surface) |
| 025-tagging-rule-management.md | Feature | Auto-Tagging | Tagging | Done | 013 | Rule list + edit/delete + stale handling, split out of 013 (shares the Settings surface with 024) |
| 026-quick-create-category-in-picker.md | Feature | Categories | Category | Done | None | Quick-create a category from inside pickCategory (name + prefilled parent, defaults for the rest) |
| 027-app-icon-and-branding.md | Feature | Setup | Infra | Done | None | Money-bag launcher icon (adaptive + monochrome) and launch screen via flutter_native_splash |
| 029-menu-tab-for-rare-surfaces.md | Feature | None | Infra | Done | None | Bottom nav stays at Konten \| Report \| Mehr; rare surfaces (Prognose, later 022/024/025) live behind a menu screen |
| 028-milestone-1-verification-pass.md | TechDebt | None | Infra | In Progress | 024, 025, 026 | One device + visual pass over all of milestone 1 — collects every check `make check` cannot make (native halves, rendering, gestures); carries 022 + 014 visual checks |
| 030-r8-mlkit-missing-classes.md | Bug | Setup | Infra | Done | None | Release build dies in R8: google_mlkit_text_recognition references the unused Chinese/Devanagari/Japanese/Korean recognizers |
| 031-theme-mode-setting.md | Feature | Setup | Infra | Ready | None | Theme mode row in Settings: Dunkel / Hell / Systemvorgabe (default), dark scheme from the same teal seed |
| 032-transfers-between-own-accounts.md | Feature | None | Transaction | Draft | None | Transfers between own accounts count as expense + income and inflate the report; model has no notion of them |
| 033-pdf-receipts-for-drilldown.md | Feature | Drilldown | Drilldown | Draft | None | PDF receipts (Amazon et al.) as a line-item source: text layer instead of OCR, parser + source model open |
| 034-r8-strips-mlkit-recognizer.md | Bug | Setup | Infra | Draft | None | Release APK cannot read receipts: `-dontwarn` from 030 let R8 strip the ML Kit recognizer classes |
| 035-skewed-receipt-shifts-prices.md | Bug | Drilldown | Drilldown | Draft | None | Skew pairs every price with the neighbouring item, and address/total/Bargeld/Rückgeld/EC rows arrive as positions |
| 036-v2-receipt-verification-checklist.md | TechDebt | None | Drilldown | Draft | 034, 035, 033 | Device checks for the receipt pipeline after its fixes, plus the human checks for PDF receipts |
