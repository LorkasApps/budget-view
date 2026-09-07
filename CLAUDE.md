# BudgetView

Flutter/Dart, Android-only. Local-first budget app on Isar, Riverpod for state.
Feature-first layout under `lib/features/<domain>/{data,domain,presentation}`.

## Read docs before code

1. `.claude/docs/README.md` — index of every feature doc
2. the relevant feature doc, plus `dependencies.md` for domain boundaries
3. `decisions.md` before proposing architecture — it says why, so you do not re-litigate

Ask for specific paths before reading source. Docs are cheap, code is not.

## Tickets

`.claude/tickets/README.md` is the index. Every request becomes a ticket first:
`Draft → Ready → In Progress → Done`. Never start implementing a `Draft`, and
never mark `Done` with an unchecked AC.

## Commands

| Command | Does |
|---------|------|
| `make check` | analyze + test — the gate before any commit |
| `make test-name NAME="..."` | one suite |
| `make gen` | code generation (Isar `*.g.dart`) |
| `make run` / `make run-release` | debug / release on the device |
| `make release-check` | check + APK; R8 runs nowhere else |
| `make help` | everything else |

## Cheap lookups first

In this order, never skipping down:

1. **Helper script** — `.claude/helper/README.md`. `doc_section.py` for a slice
   of a long doc, `ticket_status_count.py` for backlog state, `check.py` for the
   gate. A question needing three files read is a helper, not three reads.
2. **LSP for symbols** — `goToDefinition`, `findReferences`, `documentSymbol`,
   `workspaceSymbol`. Anything shaped like an identifier goes here. Grep is for
   strings and phrases: error messages, German UI text, config keys.
3. **Explore subagent** for open-ended recon — "how does X work", "where does Y
   live". Past three file-locator queries it belongs in a subagent, so the grep
   dumps stay in its context and only the summary comes back.
4. **Read** last, with `offset`/`limit` before the whole file.

`*.g.dart`, `build/`, `.dart_tool/` and `*.lock` are blocked outright — see
`guard_paths.py`. If a read is refused, that is the rule working, not a bug.

## Gotchas

- **Flutter does not run in the agent sandbox.** The user runs every check and
  pastes the output. Never claim a suite is green without it.
- **ML Kit has no test-VM binding**, so real OCR is unverifiable offline;
  layout rules are tested against dumped coordinates (`decisions.md`, 2026-08-17).
- **Isar never completes inside `testWidgets`** — cross-cutting services are an
  interface plus a `Local` implementation so widget tests can fake them.
- **Raw documents are never persisted.** Statements and receipt photos are read
  once and the bytes dropped; nothing real lands in git.
- **"Not set" is `null` everywhere**, no empty-string sentinel. Money is int64 cents.
- Commits are `type: subject` — no scope in parentheses, no AI attribution.
