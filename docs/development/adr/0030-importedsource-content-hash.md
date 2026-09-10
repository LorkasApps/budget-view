---
title: "ImportedSource entity: SHA-256 content hash plus metadata per import"
date: 2026-08-10
tags:
  - adr
description: Each import is recorded as an ImportedSource with a SHA-256 content hash and metadata, powering a re-import warning that covers both PDF and photo imports.
---

# 0030 — ImportedSource entity: SHA-256 content hash plus metadata per import

**Status:** Accepted, 2026-08-10

## Context

Raw documents are not persisted (0029), but the app still needs a way to warn a user who imports the same file twice.

## Decision

`ImportedSource` entity: `contentHash` SHA-256 plus metadata, per import.

## Consequences

This powers a re-import warning ("this file was already imported on ...", `"diese Datei schon am ... importiert"`), covering both PDF and photo imports (`Deckt PDF- + Foto-Imports`).

## Evidence

> [!NOTE]
> Not cited. Migrated from `decisions.md`, which was kept without `file:line` references.
> Verify against current code before acting on this record.
