---
title: Architecture Decisions
date: 2026-09-10
description: One record per architectural decision, oldest first, so a settled question is not reopened.
---

# Architecture Decisions

One file per decision, `NNNN-<english-kebab-slug>.md`, numbered oldest first. Check this table
before asking "why was X done this way" — the answer is likely already here.

Records migrated from the former `decisions.md` carry a gap marker instead of an Evidence section:
that table was kept without `file:line` citations, and inventing them afterwards would be guessing.
Every **new** ADR cites the code that implements it, and a citation is re-verified before it is
acted on, because line numbers rot.

| ADR | Date | Decision |
|-----|------|----------|
