---
title: "Only the ING Girokonto and TR Cashkonto are importable; ING Extrakonten are maintained by hand"
date: 2026-08-24
tags:
  - adr
description: Only ING checking and TR cash accounts get statement import; ING side accounts (custody reference, savings) receive no statements at all, striking the 040 assumption that securities debits appear as rows on the checking-account statement.
---

# 0129 — Only the ING Girokonto and TR Cashkonto are importable; ING Extrakonten are maintained by hand

**Status:** Accepted, 2026-08-24

## Context

ING `Extrakonten` get no statements at all — the custody reference account (`Depot-Referenzkonto`) only produces settlements (`Abrechnungen`) and custody statements (`Depotauszüge`). The sought-after securities line therefore exists on no document a parser reads, and the earlier assumption only held for custody accounts settled through the checking account. This strikes the 040 assumption that "securities debits appear as rows on the checking-account statement."

## Decision

Importable accounts are only the ING checking account (`Girokonto`) and the TR cash account (`Cashkonto`); ING `Extrakonten` (custody reference, savings/`Tagesgeld`) are maintained by hand.

## Consequences

Beyond 040: for a transfer Giro → Extra, only the Giro side carries a document — the other side is manual work, which makes the transfer-marking decision from 032 (0113) weigh more heavily than assumed at design time. Dividends and interest arrive via the TR statement. Settlement and custody statements are PDFs; a parser behind the same `PdfParser` seam remains possible later, but is deliberately not filed as a ticket yet.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
