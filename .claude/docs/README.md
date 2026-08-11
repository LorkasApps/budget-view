# Feature Documentation

| File | Domain | Summary |
|------|--------|---------|
| infrastructure.md | Infra | Stack, feature-first layout, entry point, dev commands (Makefile) |
| sync.md | Infra | Sync stub: SyncableEntity, ChangeQueueEntry, LocalSyncAdapter, repo-layer contract |
| account.md | Account | Account entity, repository (sync-wired), providers, validation, list/form UI, money helpers |
| category.md | Category | Category tree entity, repository (sync-wired, exceptions), tree helpers, providers, validation, tree/form UI (expandable, drag-reorder, icon/color pickers) |
| transaction.md | Transaction | Transaction entity, repository (+sumForAccount), providers, validation, list/form UI, balance integration |
| import.md | Transaction | PDF import layer: PdfParser interface, registry (IngGiroParser), ING layout parsing, import flow (preview, edit, persist via controller) |
