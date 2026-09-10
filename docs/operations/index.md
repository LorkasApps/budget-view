---
title: Operations
date: 2026-09-10
description: Troubleshooting entries for symptoms already hit once in BudgetView development.
---

# Operations

BudgetView deploys no running service, so this section carries only what a recurring symptom
needs. There are no runbooks, no on-call rotation and no incident writeups, because there is no
production system to operate.

| Directory | Holds |
|-----------|-------|
| [troubleshooting/](troubleshooting/index.md) | One page per symptom seen before, with the check that confirms it |

The standard hierarchy files troubleshooting under `operations/` and reserves `operations/` for
repositories that deploy a service. That friction is accepted knowingly: a recurring symptom has
no other standard home, and inventing a local one would be the larger deviation.
