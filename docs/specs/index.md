---
title: Specs
date: 2026-09-10
description: Feature and bug specs for BudgetView, one shared three-digit sequence across both directories.
---

# Specs

Every request becomes a spec before any code is written: `Draft → Ready → In Progress → Done`.
A `Draft` is never implemented, and a spec is never `Done` with an unchecked acceptance criterion.

| Directory | Holds |
|-----------|-------|
| [features/](features/index.md) | Features and TechDebt |
| [bugs/](bugs/index.md) | Bugs |

## Numbering

Both directories share **one** `NNN` sequence, so an ID identifies a spec without naming its
directory and a cross-reference stays valid if a bug turns out to be a feature. Filenames are
`NNN-kebab-slug.md`, English, slug capped at 40 characters after the prefix.

TechDebt lives in `features/` and keeps `TechDebt` in its `Type` field. The hierarchy has no
TechDebt directory, and adding one would be the larger deviation.
