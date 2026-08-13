# Helpers

Python 3, stdlib only. Read-only unless prefixed `mutate_`. Operate on `.claude/` + git metadata only. Never scan source code.

## `test_summary.py`

Compacts `make check` output (`flutter analyze` + `flutter test`) down to failures only, so raw passing-test noise never has to be dumped into an LLM context.

**Usage:** `make check 2>&1 | ./.claude/helper/test_summary.py [flags]`

**Always merge stderr.** `flutter test` writes its exception dumps to stderr while the failing `[E]` progress line goes to stdout. Piping stdout alone reduces every widget failure to a useless `Test failed. See exception logs above.`

**Args:**
- `--context N` (optional, default `3`) — lines of stack trace to keep per failure
- `--format {dart,auto}` (optional, default `auto`) — parser to use; `auto` currently resolves to `dart` (flutter analyze + flutter test output). Kept simple so more formats can be added later.
- `--skip-info` (optional, default off) — drop flutter analyze `info` findings. Off by default: `flutter analyze` exits non-zero on `info`, so hiding them hides the reason `make check` failed.

**Output:** an optional `ANALYZE` heading listing analyze findings (with the issue tally when reported), then one block per failing test (test name, assertion/first message line, up to `--context` stack lines), blocks separated by `---`, ending with a single summary line such as `12 passed, 1 failed, 0 skipped` (or `summary unavailable` if counts can't be determined — e.g. when `make check` aborts at the analyze step before any test runs).

**Example:**

    $ make check | ./.claude/helper/test_summary.py
    ANALYZE (1 issue(s) reported)
    error • Undefined name 'foo' • lib/foo.dart:10:5 • undefined_identifier
    ---
    Widget shows balance
    Expected: <5>
      Actual: <4>
    test/widgets/balance_test.dart 45:5  main.<fn>
    ---
    12 passed, 1 failed, 0 skipped

**Exit codes:** `0` analyze clean and all tests passed, `1` any analyze issue or test failure, `2` input was empty or could not be parsed.

## `line_length.py`

Lists Dart lines over a width limit. A diagnostic, not a gate: nothing in `analysis_options.yaml` enables `lines_longer_than_80_chars`, and the repo has pre-existing long lines (mostly `import 'package:...'`, which `dart format` never rewraps). It exists because `dart format` cannot run in the agent sandbox, so wrapping is otherwise unverifiable from there.

**Prints positions and lengths only, never line content** — the one way a source-touching helper stays compatible with the "no source code in context" rule. Read it as a tally, not as a diff.

**Usage:** `./.claude/helper/line_length.py [paths...] [--max N] [--changed] [--quiet]`

**Args:**
- `paths` (optional, default `lib test`) — files or directories to scan; `*.g.dart` is always skipped
- `--max N` (optional, default `80`) — width limit
- `--changed` (optional) — only files modified against `HEAD`, **including untracked ones** (`git diff` alone never lists new files, which are exactly the ones worth checking). Ignores `paths`
- `--quiet` (optional) — per-file counts instead of individual positions

**Output:** tab-separated `<path>:<line>\t<length>`, or `<path>\t<count>` with `--quiet`, then a tally line.

**Example:**

    $ ./.claude/helper/line_length.py --changed --quiet
    lib/features/tagging/data/tagging_rule.dart	1
    2 line(s) over 80 chars in 12 file(s)

**Exit codes:** `0` nothing over the limit (or nothing to scan), `1` at least one line over the limit.

## `ticket_status_count.py`

Ticket progress from `.claude/tickets/README.md` — counts per epic/domain/type, or lists the tickets behind one status.

**Usage:** `./.claude/helper/ticket_status_count.py [--by {epic,domain,type}] [--status STATUS] [--file PATH]`

**Args:**
- `--by` (optional, default `epic`) — grouping for the count matrix
- `--status` (optional) — list matching tickets instead of counting: `Draft`, `Ready`, `In Progress`, `Done`. `Draft (post-V1)` is normalised to `Draft`
- `--file` (optional, default `.claude/tickets/README.md`) — alternative table path

**Output:** matrix mode is tab-separated `<group>\ttotal\t<one column per status present>` with a trailing `TOTAL` row. List mode is tab-separated `<id>\t<epic>\t<domain>\t<blocked by>\t<summary>`, ascending by id.

**Example:**

    $ ./.claude/helper/ticket_status_count.py
    epic    total   Draft   Ready   Done
    Accounts        2       0       0       2
    Import  4       0       1       3
    Setup   3       0       0       3
    TOTAL   23      1       14      8

    $ ./.claude/helper/ticket_status_count.py --status Ready
    009     Import  Transaction     006, 008        Duplicate detection (tx-level + doc-level SHA-256)

**Exit codes:** `0` OK, `1` tickets README not found, `2` table malformed or no ticket rows, `3` no ticket matched `--status`.
