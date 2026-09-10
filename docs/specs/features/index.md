---
title: Features
date: 2026-09-10
description: Feature and TechDebt specs with status, epic, domain and blocking relationships.
---

# Features

The column names below are a contract: `.claude/helper/ticket_status_count.py` and its siblings key
off this header row and read the filename out of the markdown link in the `File` cell. Extra columns
are fine, renamed ones break the helpers.

`Blocked By` lists specs that must be `Done` before this one may move to `In Progress`. Reaching
`Ready` with open blockers is allowed — acceptance criteria can be tightened while a blocker is
still open.

| File | Type | Epic | Domain | Status | Blocked By | Summary |
|------|------|------|--------|--------|------------|---------|
