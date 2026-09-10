---
title: BudgetView Documentation
date: 2026-09-10
description: Entry point to the specs, development reference, decisions and troubleshooting for the BudgetView Flutter app.
---

# BudgetView Documentation

Local-first budget app: Flutter/Dart, Android only, Isar for storage, Riverpod for state.
Feature-first layout under `lib/features/<domain>/{data,domain,presentation}`.

Nothing here is published to a documentation server. The MDBunker hierarchy is used for its
shape, not for hosting — this is a private repository.

## Where To Look

| Section | Answers |
|---------|---------|
| [specs/](specs/index.md) | What is being built, what broke, what is still open |
| [development/](development/index.md) | How the code is organised, why it is organised that way, how to run it |
| [operations/](operations/index.md) | A symptom you have hit before |

## Start Here

- Working on a request → [specs/index.md](specs/index.md), the ticket comes before the code
- Planning a change → [development/reference/index.md](development/reference/index.md), then
  [development/adr/index.md](development/adr/index.md) so a settled decision is not reopened
- Setting up or running the app → [development/HANDBOOK.md](development/HANDBOOK.md)

## Reading Order That Keeps Costs Down

Every index row and every `description` field exists so a page can be skipped without opening it.
Read the index first, decide, then open one page. For a long page pull a single section with
`.claude/helper/doc_section.py <file> <heading>` instead of reading the whole file.
