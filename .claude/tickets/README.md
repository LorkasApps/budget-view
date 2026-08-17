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
| 014-auto-suggest-on-import.md | Feature | Auto-Tagging | Tagging | Ready | 013 | Suggest category on new imports |
| 015-line-item-entity.md | Feature | Drilldown | Drilldown | Done | 006 | Line-item entity (child of transaction) |
| 016-kassenbon-photo-capture.md | Feature | Drilldown | Drilldown | Done | 015, 009 | Camera / gallery capture flow (ephemeral, no persistence) |
| 017-ocr-mlkit.md | Feature | Drilldown | Drilldown | Ready | 016 | OCR via Google ML Kit (in-memory only) |
| 018-ocr-to-line-items.md | Feature | Drilldown | Drilldown | Ready | 017 | Parse OCR text into line-items (heuristic + user review) |
| 019-sum-validation.md | Feature | Drilldown | Drilldown | Done | 015 | Auto-managed Restposten (invariant sum) |
| 020-monthly-category-report.md | Feature | Analytics | Analytics | Ready | 006, 011, 012, 015 | Monthly report: donut + tree-aware table |
| 021-forecast-linear-regression.md | Feature | Analytics | Analytics | Ready | 020 | Forecast (LR, user-picked window + horizon) |
| 022-item-price-trends.md | Feature | Analytics | Analytics | Ready | 015, 018 | Item price trends (auto-group by normalized description) |
| 023-unit-price-normalization.md | Feature | Analytics | Analytics | Draft (post-V1) | 015, 018, 022 | Weight-based unit-price for variable-weight items (€/kg, €/l) |
| 024-import-history-screen.md | Feature | Import | Import | Draft | 009 | ImportedSource list + delete, split out of 009 (needs a Settings surface) |
| 025-tagging-rule-management.md | Feature | Auto-Tagging | Tagging | Draft | 013 | Rule list + edit/delete + stale handling, split out of 013 (shares the Settings surface with 024) |
| 026-quick-create-category-in-picker.md | Feature | Categories | Category | Draft | None | Quick-create a category from inside pickCategory (name + prefilled parent, defaults for the rest) |
| 027-app-icon-and-branding.md | Feature | Setup | Infra | Ready | None | Money-bag launcher icon (adaptive + monochrome) and launch screen via flutter_native_splash |
