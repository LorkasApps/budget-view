# Feature Documentation

| File | Domain | Summary |
|------|--------|---------|
| infrastructure.md | Infra | Stack, feature-first layout, entry point, dev commands (Makefile) |
| sync.md | Infra | Sync stub: SyncableEntity, ChangeQueueEntry, LocalSyncAdapter, repo-layer contract |
| account.md | Account | Account entity, repository (sync-wired), providers, validation, list/form UI, money helpers |
| category.md | Category | Category tree entity, repository (sync-wired, exceptions), tree helpers, providers, validation, tree/form UI (expandable, drag-reorder, icon/color pickers) |
| transaction.md | Transaction | Transaction entity, repository (+sumForAccount), providers, validation, list/form UI, balance integration |
| drilldown.md | Drilldown | LineItem entity, repository (sign follows parent, reorder), validation + mismatch warning, section/sheet inside the booking form |
| receipt-scan.md | Drilldown | Ephemeral receipt photo capture: source picker, doc-hash check, OCR/parser seams, confirm → line-items + ImportedSource |
| tagging.md | Tagging | TaggingRule entity, repository (upsert/hit-count, hard delete, remap), learn service + its three UI call sites, suggest service + shared suggestion sheet |
| import.md | Transaction | PDF import layer: PdfParser interface, registry (IngGiroParser), ING layout parsing, import flow (preview, edit, persist via controller) |
| analytics.md | Analytics | Monthly category report: rollup service, donut + tree table, month/account/direction filters, subtree drilldown; linear-regression forecast on the same rollup, chart + entry points; item price trends with search + chart UI |
