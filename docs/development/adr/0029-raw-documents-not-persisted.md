---
title: Raw documents (PDFs and receipt photos) are not persisted
date: 2026-08-10
tags:
  - adr
description: Raw PDFs and receipt (Kassenbon) photos are evaluated once and their bytes discarded; only the extracted transactions/line-items plus metadata are kept.
---

# 0029 — Raw documents (PDFs and receipt photos) are not persisted

**Status:** Accepted, 2026-08-10

## Context

Raw documents — PDFs and receipt (`Kassenbon`) photos — only need to be read once to extract data from them.

## Decision

Raw documents (PDFs + `Kassenbon` photos) are NOT persisted.

## Consequences

They are evaluated only once and the bytes discarded (`Nur einmal ausgewertet, Bytes verworfen`); only the extract (transactions / line-items) plus metadata remain (`nur Extrakt (Transaktionen / Line-Items) + Metadata bleiben`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
