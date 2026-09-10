# Move the documentation into the MDBunker hierarchy

| Field | Value |
|-------|-------|
| **Type** | TechDebt |
| **Epic** | None |
| **Domain** | Infra |
| **Blocked By** | None |
| **Severity** | Low |
| **Effort** | XL |
| **Status** | Done |

## Description
`.claude/` currently holds both tooling and documentation. The MDBunker hierarchy separates the two: documentation moves to
`docs/`, `.claude/` keeps helpers, hooks and commands. The value is not publishing — this is a private repo and nothing goes to
the MDBunker server — it is the shape: per-directory `index.md`, YAML frontmatter with a `description` that decides whether a
page is opened at all, one file per decision, one page per symptom.

**Risk if ignored:** none acute. The present layout works. This is a bet that the standard shape reads better at the size the
docs have reached — 14 documents, 149 decisions, 62 tickets — and that a known hierarchy beats a local convention when a
future session has to find something.

Two rules collide here and the collision is deliberate, not an oversight. The MDBunker structure guide says an older layout
must be rewritten into the standard hierarchy. The `basic-stuff` skill says an old layout is left alone and migrated only when
the user asks for it as its own task. The skill wins on timing — this ticket exists because the user asked — and the server
wins on target shape.

Tickets 052 and 055 are `In Progress` while this runs, so their files move mid-flight. Harmless: both are code-complete and
committed, only a device check is open, and a device check does not care which path the ticket file sits at.

## Resolved before refinement
Answered by the user on 2026-09-10, in the scoping round:

- **`decisions.md` becomes 149 separate ADRs** under `docs/development/adr/`, standard-conform, plus a 149-row `index.md`.
  Chosen against the recommendation to keep one grep-able table; the standard shape won
- **Content language is English**, so the 149 German decision texts are translated. Accepted risk: a translation can distort
  a rationale, and the German original survives only in git history once `decisions.md` is deleted. Mitigation is model
  choice — this step goes to Sonnet, not Haiku
- **Evidence sections carry an explicit gap marker**, not invented `file:line` citations. `decisions.md` has zero citations
  today, and deriving 149 of them would mean 149 source lookups against the docs-before-code rule, for line numbers that rot
  on the next refactor. New ADRs from now on cite properly
- **`errors.md` becomes 16 pages** under `docs/operations/troubleshooting/`, each in the 7-section shape (Symptom, Impact,
  Likely cause, Diagnosis, Fix, Prevention, Escalation). Formal friction accepted: the server says `operations/` exists only
  in repos that deploy a running service, and this one deploys nothing. Recurring symptoms have no other standard home
- **The 2 TechDebt tickets go to `docs/specs/features/`**, keeping their `Type` field. `specs/` has no TechDebt directory and
  inventing one would be the larger deviation
- **Directly on main, one commit per step**, each independently revertable

## Not migrated, and why
- **`docs/design/`** — the server creates it only for repos with a UI surface, which this is, but there is no existing
  `DESIGN.md`, `PALETTE.md` or `TYPOGRAPHY.md` content. Writing four pages from nothing would be inventing facts. Created when
  there is something true to put in it
- **`docs/manuals/`** — one user, who is the author
- **`CLAUDE.md` stays at the repo root.** It is the agent-facing index, reloaded every message, and not MDBunker documentation

## Acceptance Criteria
- [x] `docs/` exists with `index.md` in every non-asset directory, and every index links only to pages that exist
- [x] The 10 feature docs plus `glossary.md` and `dependencies.md` live under `docs/development/reference/` — 12 pages.
      This ticket claimed 13 before anyone counted; the figure was wrong, not the work. Each with YAML
      frontmatter carrying at least `title`, `date` and `description`; the `description` is specific enough to decide against
      opening the page
- [x] `dependencies.md` states the domain graph as a Mermaid diagram rather than an arrow list
- [x] 149 ADRs under `docs/development/adr/`, named `NNNN-<english-kebab-slug>.md`, numbered oldest-first by the date in
      `decisions.md`, each with Status, Context, Decision, Consequences and a gap-marked Evidence section
- [x] The ADR `index.md` carries one row per decision with its date, so the table answers "was this decided already" without
      opening a file
- [x] 16 troubleshooting pages under `docs/operations/troubleshooting/`, each titled after the user-visible symptom plus the
      system term, each in the 7-section shape. Where the source row has no Diagnosis or Prevention, the section says so
      instead of inventing one
- [x] The 63 specs live under `docs/specs/features/` (48 Feature + 3 TechDebt) and `docs/specs/bugs/` (12 Bug), with the
      shared `NNN` sequence intact and no renumbering. 63 rather than 62 because this ticket counts itself, and the third
      TechDebt is this one
- [x] Both spec indexes use the contract column names — `File`, `Type`, `Epic`, `Domain`, `Status`, `Blocked By`, `Summary`
- [x] `docs/development/HANDBOOK.md` exists and holds the contributor loop: the Makefile targets, the gate before a commit,
      and the fact that Flutter does not run in the agent sandbox. `CLAUDE.md` points at it instead of restating it
- [x] `doc_section.py`, `ticket_status_count.py` and `guard_paths.py` operate on the new paths, and their self-tests pass —
      `guard_paths.py` had 21 cases and now has 22, the added one covering a spec path
- [x] `.claude/docs/` and `.claude/tickets/` are gone, not left as stubs. No file lives in both layouts at any commit that
      ends a step
- [x] `CLAUDE.md` names the new paths, is still under 200 lines, and its edit is the **last** commit of the migration —
      editing it earlier busts the cached prefix for every following step
- [x] `make check` green after every commit that touches a helper or `CLAUDE.md`
- [x] No source file under `lib/` or `test/` is modified by this ticket

## Refactor strategy
Seven commits, in this order, because each one leaves the repo consistent:

| # | Commit | Model | Content |
|---|--------|-------|---------|
| 1 | `chore:` | Opus | `docs/` skeleton, every `index.md` as a stub with frontmatter. Kept on the main model against the user's routing preference: these nine stubs fix the frontmatter and column contract that the 227 later files and three helpers build on, so an error here is an error 227 times |
| 2 | `docs:` | Haiku | 13 reference pages moved via `git mv`, frontmatter added, Mermaid for `dependencies.md` |
| 3 | `docs:` | **Sonnet** | 149 ADRs, translated. The judgment step |
| 4 | `docs:` | **Sonnet** | 16 troubleshooting pages in the 7-section shape |
| 5 | `docs:` | Haiku | 62 tickets moved, both spec indexes built from the old README table |
| 6 | `refactor:` | Opus | The three helpers repointed. Code, not text |
| 7 | `docs:` | Opus | `HANDBOOK.md` written, `CLAUDE.md` repointed. Last, for the cache |

`git mv` throughout, so history follows the files. Steps 3 and 4 are the only ones that rewrite content rather than move it,
and both get a spot-check against the German original before their commit.

## Affected Tests
None under `lib/` or `test/`. The checks that matter are the helper self-tests, `guard_paths.py` above all, since its deny
patterns name `.claude/` paths that change.

## Fixtures Needed
No.

### Refinement Tokens
The scoping round of 2026-09-10 served as the refinement: six questions, all forks closed, ACs concrete before any
file moved. No separate Draft walk. Figures are inside the implementation block below, the same session.

### Implementation Tokens (measured)
- Source: `/usage`. Shared session with ticket 050, which stood at $5.56 when it closed, so the migration is the
  **$30.89** difference to the $36.45 session total. 1h03m API time, 2h12m wall
- Opus: 660 input, 138.6k output, 34.5m cache read, 961.7k cache write — $26.72
- Sonnet: 2.9k input, 166.5k output, 5.9m cache read, 298.7k cache write — $8.99
- Haiku: 7.9k input, 12.3k output, 202.5k cache read, 45.7k cache write — $0.73

**What the numbers say, which is not what was planned.**

Sonnet earned its place: it produced **more output than Opus** — 166.5k against 138.6k tokens, the 149 ADRs and the 16
troubleshooting pages — for a quarter of the cost. That delegation was the right call and would be again.

Haiku produced nothing. Both Haiku agents died before touching a file, because the briefs told them to use `mv` and
sub-agents have no Bash access here; they cannot ask for a permission either, so they simply give up. The $0.73 bought two
failure reports. Steps 2 and 5 were then done with throwaway Python scripts, which was **cheaper than either model** and
also caught two things an LLM would likely have smoothed over: spec 029's escaped pipes, and the 028/029 row order.

The dominant cost is none of that. It is Opus **cache read: 34.5m tokens**, from driving 30-odd turns of migration on top of
a conversation that already carried all of ticket 050. The baseline's own rule — one session, one logical task, `/clear`
between them — was broken by continuing here, and that single decision outweighs every model-routing choice in this ticket.
