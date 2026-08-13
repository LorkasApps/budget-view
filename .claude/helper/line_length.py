#!/usr/bin/env python3
"""Report Dart lines exceeding a width limit.

Nothing in analysis_options.yaml enables `lines_longer_than_80_chars`, so this
is a diagnostic rather than a gate. It exists because `dart format` cannot run
inside the agent sandbox, and a wrapped-looking file is otherwise impossible to
verify from here.

Deliberately prints positions and lengths only, never line content: helpers are
not allowed to pull source code into an LLM context, and a width report does not
need the text to be useful.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

DEFAULT_PATHS = ("lib", "test")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="List Dart lines longer than --max chars (positions only).",
        epilog="Long `import 'package:...'` lines are expected: dart format "
        "never rewraps them. Generated *.g.dart files are always skipped.",
    )
    parser.add_argument(
        "paths",
        nargs="*",
        default=list(DEFAULT_PATHS),
        help=f"files or directories to scan (default: {' '.join(DEFAULT_PATHS)})",
    )
    parser.add_argument(
        "--max",
        type=int,
        default=80,
        help="width limit in characters (default: 80)",
    )
    parser.add_argument(
        "--changed",
        action="store_true",
        help="only files modified against HEAD (git metadata, not a full scan)",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="print just the per-file tally, no individual positions",
    )
    return parser.parse_args()


def _git_lines(*args: str) -> list[str]:
    result = subprocess.run(
        ["git", *args],
        capture_output=True,
        text=True,
        check=False,
    )
    return result.stdout.splitlines() if result.returncode == 0 else []


def changed_dart_files() -> list[Path]:
    """Dart files touched in the working tree, staged or not.

    Untracked files are included on purpose: brand-new files are the ones worth
    checking, and `git diff` alone never lists them.
    """
    names = _git_lines("diff", "--name-only", "--diff-filter=ACMR", "HEAD")
    names += _git_lines("ls-files", "--others", "--exclude-standard")
    return [
        Path(name)
        for name in sorted(set(names))
        if name.endswith(".dart") and not name.endswith(".g.dart")
    ]


def collect(paths: list[str]) -> list[Path]:
    files: list[Path] = []
    for raw in paths:
        path = Path(raw)
        if path.is_file():
            if path.suffix == ".dart" and not path.name.endswith(".g.dart"):
                files.append(path)
            continue
        files.extend(
            candidate
            for candidate in sorted(path.rglob("*.dart"))
            if not candidate.name.endswith(".g.dart")
        )
    return files


def offenders(path: Path, limit: int) -> list[tuple[int, int]]:
    """(line number, length) for every line over the limit."""
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return []
    return [
        (number, len(line))
        for number, line in enumerate(text.splitlines(), start=1)
        if len(line) > limit
    ]


def main() -> int:
    args = parse_args()

    files = changed_dart_files() if args.changed else collect(args.paths)
    files = [path for path in files if path.exists()]
    if not files:
        print("no Dart files to scan")
        return 0

    total = 0
    for path in files:
        hits = offenders(path, args.max)
        if not hits:
            continue
        total += len(hits)
        if args.quiet:
            print(f"{path}\t{len(hits)}")
            continue
        for number, length in hits:
            print(f"{path}:{number}\t{length}")

    print(f"{total} line(s) over {args.max} chars in {len(files)} file(s)")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
