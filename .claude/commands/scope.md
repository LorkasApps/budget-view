---
description: Pull task context out of the user's head as a multiple-choice questionnaire before any code is planned
---

Do not write code. Do not read source files yet. Produce a scoping questionnaire.

<task>
Draft `userinput.md` in the repo root: every open question you have about the work described below, as **multiple choice**. The user answers by editing the file in place.
</task>

<rules>
- Batch ALL questions in one pass. This is the scoping phase — serial Q&A here wastes turns.
- Every question gets 2-4 concrete options plus `Other: ___`. Never open-ended prose questions.
- Mark your recommended option with `(rec)` and one clause of reasoning.
- Cover: scope boundaries, data shape, error behavior, auth/permissions, migration/backfill need, test depth, out-of-scope items.
- Max 12 questions. If you have more, you have not scoped tightly enough — split the work.
- Do not ask what the codebase can answer. Ask what only the user knows.
</rules>

<format>
# Scope: <task name>

## 1. <question>
- [ ] a) <option>  (rec — <why>)
- [ ] b) <option>
- [ ] Other: ___

## 2. <question>
...

## Out of scope (confirm)
- [ ] <thing you are assuming is NOT included>
</format>

After writing the file, stop and report only: path + question count. Wait for the user to fill it in.

Once answers come back, build the step plan: small self-contained steps, each with a finish line and a check. Any step still needing a judgment call goes back into the plan, not into execution.

<work>
$ARGUMENTS
</work>
