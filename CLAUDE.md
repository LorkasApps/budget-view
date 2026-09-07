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

## Helper scripts before Read/Grep

`.claude/helper/README.md`. `doc_section.py` for a slice of a long doc,
`ticket_status_count.py` for backlog state, `check.py` for the gate. If a
question needs three files read, write a helper instead.

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
