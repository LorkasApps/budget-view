---
title: Development Reference
date: 2026-09-10
description: One page per feature domain, plus the domain dependency graph and the glossary.
---

# Development Reference

Current state only. If a page disagrees with the code, the code is right and the page is stale.

Read this table first and open one page. The `Summary` column and each page's `description`
frontmatter exist to let a page be skipped. For a page over roughly 150 lines, pull one section
with `.claude/helper/doc_section.py <file> <heading>` rather than reading the file.

| Page | Domain | Summary |
|------|--------|---------|
| [infrastructure.md](infrastructure.md) | Infra | Stack, feature-first layout, entry point (AppShell, MenuScreen, SettingsScreen), dev commands (Makefile) |
| [sync.md](sync.md) | Infra | Sync stub: SyncableEntity, ChangeQueueEntry, LocalSyncAdapter, repo-layer contract |
| [account.md](account.md) | Account | Account entity, repository (sync-wired), providers, validation, list/form UI, money helpers |
| [category.md](category.md) | Category | Category tree entity, repository (sync-wired, exceptions), tree helpers, providers, validation, tree/form/picker UI (expandable, drag-reorder, icon/color pickers, quick-create in picker) |
| [transaction.md](transaction.md) | Transaction | Transaction entity, repository (+sumForAccount), providers, validation, list/form UI, balance integration |
| [drilldown.md](drilldown.md) | Drilldown | LineItem entity, repository (sign follows parent, reorder), validation + mismatch warning, section/sheet inside the booking form |
| [receipt-scan.md](receipt-scan.md) | Drilldown | Ephemeral receipt capture: photo/PDF/gallery source picker, deskew, doc-hash check, OCR or PDF reading, parser seams, confirm to line-items + ImportedSource, printed total checksum banner |
| [tagging.md](tagging.md) | Tagging | TaggingRule entity, repository (upsert/hit-count, hard delete, remap), learn service + its three UI call sites, suggest service + shared suggestion sheet, TaggingRulesScreen, providers |
| [import.md](import.md) | Transaction | PDF import layer: PdfParser interface, registry (IngGiroParser), ING layout parsing, import flow (preview, edit, persist via controller), import history screen + provider, merchant extraction |
| [analytics.md](analytics.md) | Analytics | Monthly category report: rollup service, donut + tree table, month/account/direction filters, subtree drilldown; linear-regression forecast on the same rollup; item price trends with search + chart UI |
| [dependencies.md](dependencies.md) | — | Which domain may depend on which, and the reason each edge exists. Check before any cross-domain change. |
| [glossary.md](glossary.md) | — | Project vocabulary and abbreviations used in specs and reference pages. |
