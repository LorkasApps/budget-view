---
title: Detect duplicates via a hash of amount, date and description
date: 2026-08-10
tags:
  - adr
description: Duplicate transactions are detected via a hash over amount, date and description, covering both PDF-vs-manual and PDF-vs-PDF collisions.
---

# 0008 — Detect duplicates via a hash of amount, date and description

**Status:** Accepted, 2026-08-10

## Context

A user requirement calls for detecting duplicate transactions both between a PDF import and a manual entry, and between two PDF imports.

## Decision

Detect duplicates via a hash of amount, date and description.

## Consequences

This satisfies the user requirement for both the PDF-vs-manual and PDF-vs-PDF duplicate cases; no rejected alternatives were recorded for this decision.

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
