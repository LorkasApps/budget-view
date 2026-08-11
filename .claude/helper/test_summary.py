#!/usr/bin/env python3
"""Compact `make check` output to failures-only.

Reads combined `flutter analyze` + `flutter test` output from stdin and
prints a short summary: any analyze errors/warnings, one block per failing
test (name + assertion message + limited stack trace), and a single counts
line. Purpose: raw flutter test/analyze output is thousands of lines of
passing-test noise that must never be dumped into an LLM context.
"""

import argparse
import collections
import re
import sys

# --- Regexes for the "dart" (flutter analyze + flutter test) format -------

# Progress/summary line, e.g.:
#   00:02 +12: some test name
#   00:02 +12 -1: some test name [E]
#   00:03 +10 ~1 -1: some test name [E]
#   00:05 +12 -1: Some tests failed.
#   00:05 +13: All tests passed!
PROGRESS_RE = re.compile(
    r'^\d{2}:\d{2}\s+\+(\d+)(?:\s+~(\d+))?(?:\s+-(\d+))?:\s*(.*)$'
)

# flutter analyze finding, e.g.:
#   error • Undefined name 'foo' • lib/foo.dart:10:5 • undefined_identifier
#      info • Unused import • lib/foo.dart:3:8 • unused_import
ANALYZE_RE = re.compile(r'^\s*(info|warning|error)\s*•\s*(.*)$')

# flutter analyze tail, e.g. "1 issue found. (ran in 2.4s)" / "No issues found!"
ISSUE_COUNT_RE = re.compile(r'^\s*(\d+)\s+issues?\s+found\.')
NO_ISSUES_RE = re.compile(r'^\s*No issues found!')


def parse_dart(lines, context, include_info):
    """Parse combined flutter analyze + flutter test output.

    Returns (analyze_findings, failures, counts, analyze_issues) where:
      - analyze_findings: list[str] of formatted "severity • ..." lines
      - failures: list of dict(name=str, message=str, stack=list[str])
      - counts: dict(passed, skipped, failed) or None if never seen
      - analyze_issues: int issue count reported by flutter analyze, or None
        if analyze did not report a tally
    """
    analyze_findings = []
    failures = []
    counts = None
    analyze_issues = None

    current = None  # failure currently being collected, or None

    # Flutter prints its exception dump BEFORE the failing progress line, so the
    # detail is already gone by the time the failure is recognised. Keep a
    # rolling window and mine it for the last exception block.
    recent = collections.deque(maxlen=60)

    def preceding_detail():
        lines_before = list(recent)
        start = 0
        for index, text in enumerate(lines_before):
            if 'EXCEPTION CAUGHT' in text:
                start = index + 1

        detail = []
        for text in lines_before[start:]:
            # The stack that follows adds nothing the --context lines don't.
            if text.startswith('When the exception was thrown'):
                break
            if set(text) <= {'═', '╡', '╞', '─', '━', '='}:
                continue
            detail.append(text)
        return detail[:context + 2]

    def flush():
        if current is not None:
            failures.append(current)

    for raw_line in lines:
        line = raw_line.rstrip('\n')

        progress_match = PROGRESS_RE.match(line)
        if progress_match:
            # A progress line always terminates any failure currently
            # being collected (its detail block ends here).
            flush()
            current = None

            passed, skipped, failed, message = progress_match.groups()
            counts = {
                'passed': int(passed),
                'skipped': int(skipped) if skipped else 0,
                'failed': int(failed) if failed else 0,
            }

            message = message.strip()
            if message.endswith('[E]'):
                name = message[:-len('[E]')].strip()
                current = {
                    'name': name,
                    'detail': preceding_detail(),
                    'message': None,
                    'stack': [],
                }
            recent.clear()
            continue

        analyze_match = ANALYZE_RE.match(line)
        if analyze_match:
            severity = analyze_match.group(1)
            if severity == 'info' and not include_info:
                continue
            analyze_findings.append(f'{severity} • {analyze_match.group(2)}')
            continue

        issue_count_match = ISSUE_COUNT_RE.match(line)
        if issue_count_match:
            analyze_issues = int(issue_count_match.group(1))
            continue

        if NO_ISSUES_RE.match(line):
            analyze_issues = 0
            continue

        text = line.strip()
        if text:
            recent.append(text)

        if current is not None:
            if not text:
                continue
            if current['message'] is None:
                current['message'] = text
            elif len(current['stack']) < context:
                current['stack'].append(text)

    flush()
    return analyze_findings, failures, counts, analyze_issues


FORMAT_PARSERS = {
    'dart': parse_dart,
}


def resolve_format(fmt):
    """Map a --format value to a concrete parser name."""
    if fmt == 'auto':
        return 'dart'
    return fmt


def build_output(analyze_findings, failures, counts, analyze_issues=None):
    """Render the final compact report text (without trailing newline)."""
    sections = []

    if analyze_findings:
        heading = 'ANALYZE'
        if analyze_issues is not None:
            heading += f' ({analyze_issues} issue(s) reported)'
        sections.append(heading + '\n' + '\n'.join(analyze_findings))
    elif analyze_issues:
        # analyze failed but no finding line was captured — never stay silent
        sections.append(
            f'ANALYZE reported {analyze_issues} issue(s) but none were '
            'captured; rerun `flutter analyze` raw'
        )

    for failure in failures:
        block_lines = [failure['name']]
        block_lines.extend(failure.get('detail') or [])
        if failure['message']:
            block_lines.append(failure['message'])
        block_lines.extend(failure['stack'])
        sections.append('\n'.join(block_lines))

    if counts is None:
        summary = 'summary unavailable'
    else:
        summary = (
            f"{counts['passed']} passed, "
            f"{counts['failed']} failed, "
            f"{counts['skipped']} skipped"
        )

    body = '\n---\n'.join(sections)
    if body:
        return body + '\n' + summary
    return summary


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog='test_summary.py',
        description=(
            'Filter `flutter analyze` + `flutter test` output (as produced '
            'by `make check`) down to failures only. Reads stdin, writes a '
            'compact report to stdout: analyze errors/warnings, one block '
            'per failing test (name, assertion message, limited stack '
            'trace), then a single counts summary line.'
        ),
    )
    parser.add_argument(
        '--context', type=int, default=3,
        help='lines of stack trace to keep per failure (default: 3)',
    )
    parser.add_argument(
        '--format', choices=['dart', 'auto'], default='auto',
        help=(
            "input parser to use (default: auto). 'auto' currently "
            "resolves to 'dart' (flutter analyze + flutter test output)."
        ),
    )
    parser.add_argument(
        '--skip-info', action='store_true',
        help=(
            'drop flutter analyze "info" findings. Off by default because '
            '`flutter analyze` exits non-zero on info, so hiding them hides '
            'the reason `make check` failed.'
        ),
    )
    args = parser.parse_args(argv)

    raw = sys.stdin.read()
    if not raw.strip():
        print('test_summary: empty input, nothing to summarize', file=sys.stderr)
        return 2

    lines = raw.splitlines()

    fmt = resolve_format(args.format)
    parse_fn = FORMAT_PARSERS.get(fmt)
    if parse_fn is None:
        print(f'test_summary: unknown format: {fmt}', file=sys.stderr)
        return 2

    analyze_findings, failures, counts, analyze_issues = parse_fn(
        lines, args.context, not args.skip_info
    )

    if (
        not analyze_findings
        and not failures
        and counts is None
        and analyze_issues is None
    ):
        print('test_summary: could not parse input', file=sys.stderr)
        return 2

    print(build_output(analyze_findings, failures, counts, analyze_issues))

    if analyze_findings or analyze_issues or (counts and counts['failed'] > 0):
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
