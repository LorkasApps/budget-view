# Helpers

Python 3, stdlib only. Read-only unless prefixed `mutate_`. Operate on `.claude/` + git metadata only. Never scan source code.

## `test_summary.py`

Compacts `make check` output (`flutter analyze` + `flutter test`) down to failures only, so raw passing-test noise never has to be dumped into an LLM context.

**Usage:** `make check | ./.claude/helper/test_summary.py [flags]`

**Args:**
- `--context N` (optional, default `3`) — lines of stack trace to keep per failure
- `--format {dart,auto}` (optional, default `auto`) — parser to use; `auto` currently resolves to `dart` (flutter analyze + flutter test output). Kept simple so more formats can be added later.
- `--include-info` (optional, default off) — also report flutter analyze `info`-level findings (only `error`/`warning` are reported by default)

**Output:** an optional `ANALYZE` heading listing analyze errors/warnings, then one block per failing test (test name, assertion/first message line, up to `--context` stack lines), blocks separated by `---`, ending with a single summary line such as `12 passed, 1 failed, 0 skipped` (or `summary unavailable` if counts can't be determined).

**Example:**

    $ make check | ./.claude/helper/test_summary.py
    ANALYZE
    error • Undefined name 'foo' • lib/foo.dart:10:5 • undefined_identifier
    ---
    Widget shows balance
    Expected: <5>
      Actual: <4>
    test/widgets/balance_test.dart 45:5  main.<fn>
    ---
    12 passed, 1 failed, 0 skipped

**Exit codes:** `0` no analyze errors/warnings and all tests passed, `1` any test failure or analyze error/warning, `2` input was empty or could not be parsed.
