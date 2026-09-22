---
title: "matchField is a required parameter on the tagging read path, not a defaulted one"
date: 2026-09-22
tags:
  - adr
description: "Counterparty rules and article rules share one match-value space, so findByMatch and suggest require the caller to name the kind; a default would let Milch the shop answer a lookup for Milch the article without anyone noticing. upsert keeps its default because it has exactly one production caller."
---

# 0152 — `matchField` is a required parameter on the tagging read path, not a defaulted one

**Status:** Accepted, 2026-09-22

## Context
Ticket 056 starts learning rules keyed on an article description, beside the counterparty
rules ticket 013 already learned. `TaggingRule.matchValueNorm` is one column and the two
kinds share it — the composite unique index has always included `matchField`, so the storage
was ready, but every lookup went through `findByCounterparty`, which hard-coded the kind.

The failure mode is quiet rather than loud: a shop called `Milch` and an article called
`Milch` normalize to the same key, and a lookup that forgot to say which kind it meant would
return the other one's rules and suggest a plausible-looking wrong category. Nothing throws,
nothing logs, and the rule list afterwards looks legitimate — ticket 025 deliberately has no
bulk cleanup, so the mistake would write itself into data.

A default of `counterparty` was considered and rejected for the read path. It would have kept
all four call sites and six test fakes compiling untouched, and it matches the house style
(`excludeDeleted = true`, `windowDays = 5`). But those defaults describe a dominant case whose
wrong answer is visible; this one describes a *keyspace*, and its wrong answer is invisible.

## Decision
`TaggingRuleRepository.findByMatch(value, {required matchField})` and
`TaggingSuggestService.suggest(value, {required matchField})` require the kind. The old name
`findByCounterparty` is gone: it was a lie once the method could return article rules.

`upsert(value, categoryUuid, {matchField})` **keeps** its default. It has exactly one
production caller, `TaggingLearnService`, which passes the field explicitly on both paths; the
default is reached only by tests seeding counterparty rules, and making it required would add
noise to some twenty-five lines for no safety gain.

## Consequences
Every lookup now reads as what it is at the call site. The compiler catches an omission, which
is the only place this class of mistake can be caught — no test can prove the absence of a
collision the author never thought of.

The asymmetry between the read path and `upsert` is deliberate and worth re-checking if a
second write path ever appears: at that point the argument for the default is gone.

## Evidence
- `lib/features/tagging/domain/tagging_rule_repository.dart:54` — `findByMatch`, and the
  reason in its doc comment
- `lib/features/tagging/domain/tagging_suggest_service.dart` — the interface method and
  `LocalTaggingSuggestService`
- `lib/features/tagging/domain/tagging_learn_service.dart` — the single write path, passing
  `counterparty` for a booking and `description` for a position
- `test/features/tagging/domain/tagging_rule_repository_test.dart` — group
  `the two kinds share one value space (ticket 056)`: same text, two rules, each lookup blind
  to the other, separate hit counts
