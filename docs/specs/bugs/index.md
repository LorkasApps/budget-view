---
title: Bugs
date: 2026-09-10
description: Bug specs with status, epic, domain and blocking relationships.
---

# Bugs

Same column contract as [features/](../features/index.md), and the same shared `NNN` sequence.

A bug spec additionally carries Severity, Repro Steps, Expected vs Actual, Affected Envs,
Workaround and Since When in its own file.

| File | Type | Epic | Domain | Status | Blocked By | Summary |
|------|------|------|--------|--------|------------|---------|
| [030-r8-mlkit-missing-classes.md](030-r8-mlkit-missing-classes.md) | Bug | Setup | Infra | Done | None | Release build dies in R8: google_mlkit_text_recognition references the unused Chinese/Devanagari/Japanese/Korean recognizers |
| [034-r8-strips-mlkit-recognizer.md](034-r8-strips-mlkit-recognizer.md) | Bug | Setup | Infra | Done | None | Release APK cannot read receipts: R8 renames ML Kit's reflective internals; needs `-keep`, not `-dontwarn` |
| [035-skewed-receipt-shifts-prices.md](035-skewed-receipt-shifts-prices.md) | Bug | Drilldown | Drilldown | Done | None | Skew pairs every price with the neighbouring item, and address/total/Bargeld/Rückgeld/EC rows arrive as positions |
| [039-back-from-a-tab-exits-the-app.md](039-back-from-a-tab-exits-the-app.md) | Bug | None | Infra | Done | None | Back at tab root closes the app instead of returning to Konten; the IndexedStack has no history around it |
| [041-transfer-still-shows-category-required.md](041-transfer-still-shows-category-required.md) | Bug | None | Transaction | Done | None | Category field keeps its red required marker on a transfer although saving works |
| [043-ocr-path-misses-the-pdf-rules.md](043-ocr-path-misses-the-pdf-rules.md) | Bug | Drilldown | Drilldown | Done | None | A screenshot of a receipt is read by weaker rules than its PDF: struck-through price, credits, plausibility bound |
| [045-photographed-picnic-receipt-yields-nothing.md](045-photographed-picnic-receipt-yields-nothing.md) | Bug | Drilldown | Drilldown | Done | 043 | Raised cents split the price across OCR lines; since 035 those rows are dropped, so a photo yields almost nothing |
| [049-transfers-in-the-uncategorized-filter.md](049-transfers-in-the-uncategorized-filter.md) | Bug | None | Transaction | Done | 053 | Closed by 053: the toggle is gone and the rule lives in its `Ohne Kategorie` option, so transfers no longer clog it |
| [055-picnic-photo-still-reads-wrong.md](055-picnic-photo-still-reads-wrong.md) | Bug | Drilldown | Drilldown | In Progress | None | Pairing was the defect: the price now anchors the row, 045's raised-cents reassembly removed as refuted by the real dump. Fixture from the dump green (19 positions), device check open |
| [058-tr-import-row-without-a-readable-date.md](058-tr-import-row-without-a-readable-date.md) | Bug | Import | Transaction | Done | None | One unreadable date drops a row, the reconciliation then refuses the whole statement; likely a glued `01 Juli` token |
| [060-ambiguous-candidate-row-hides-ink.md](060-ambiguous-candidate-row-hides-ink.md) | Bug | Drilldown | Drilldown | Draft | None | An ambiguous candidate row wraps its ListTile in a coloured Container, tripping a framework assertion once per row |
| [061-picnic-pdf-counts-undelivered-rows.md](061-picnic-pdf-counts-undelivered-rows.md) | Bug | Drilldown | Drilldown | Draft | None | Real PDF dumped: `Zwischensumme` terminates the basket, but the `Hoppla` undelivered row and the `Pfand` block become positions — 129,10 € against a printed 120,91 €, with a 0,99 € residue still unexplained |
