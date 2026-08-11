# Helpers

Python 3, stdlib only. Read-only unless prefixed `mutate_`. Operate on `.claude/` + git metadata only. Never scan source code.

## `test_summary.py`

Compacts `make check` output (`flutter analyze` + `flutter test`) down to failures only, so raw passing-test noise never has to be dumped into an LLM context.

**Usage:** `make check | ./.claude/helper/test_summary.py [flags]`

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
