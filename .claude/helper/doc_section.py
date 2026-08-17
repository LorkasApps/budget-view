#!/usr/bin/env python3
"""Extract a single section from a doc under .claude/docs/ by heading."""

import argparse
import re
import sys
from pathlib import Path

DOCS_DIR = Path(__file__).resolve().parent.parent / "docs"
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*$")


def find_sections(lines, needle):
    hits = []
    for idx, line in enumerate(lines):
        m = HEADING.match(line)
        if m and needle.lower() in m.group(2).lower():
            hits.append((idx, len(m.group(1)), m.group(2)))
    return hits


def main():
    p = argparse.ArgumentParser(
        description="Print one section of a doc (heading + body up to the next "
        "same-or-higher-level heading). Cheaper than reading the whole file.",
        epilog="Example: ./.claude/helper/doc_section.py import.md 'ImportedSource'",
    )
    p.add_argument("file", help="path relative to .claude/docs/ (or a full path)")
    p.add_argument(
        "heading",
        nargs="?",
        help="heading text, case-insensitive substring match (omit with --list)",
    )
    p.add_argument(
        "--depth",
        type=int,
        default=6,
        help="max heading level kept as child; deeper siblings end the section (default 6)",
    )
    p.add_argument(
        "--list",
        action="store_true",
        help="list all headings in the file instead of extracting",
    )
    args = p.parse_args()

    path = Path(args.file)
    if not path.is_file():
        path = DOCS_DIR / args.file
    if not path.is_file():
        print(f"file not found: {args.file}", file=sys.stderr)
        return 1

    lines = path.read_text(encoding="utf-8").splitlines()

    if args.list:
        for idx, line in enumerate(lines, 1):
            m = HEADING.match(line)
            if m:
                print(f"{idx}\t{len(m.group(1))}\t{m.group(2)}")
        return 0

    hits = find_sections(lines, args.heading)
    if not hits:
        print(f"heading not found: {args.heading}", file=sys.stderr)
        return 2
    if len(hits) > 1:
        print(
            "ambiguous match: " + ", ".join(f"{t} (line {i + 1})" for i, _, t in hits),
            file=sys.stderr,
        )
        return 3

    start, level, _ = hits[0]
    end = len(lines)
    for idx in range(start + 1, len(lines)):
        m = HEADING.match(lines[idx])
        if m and len(m.group(1)) <= max(level, min(args.depth, 6)) and len(m.group(1)) <= level:
            end = idx
            break
        if m and len(m.group(1)) > level and len(m.group(1)) > args.depth:
            end = idx
            break
    print("\n".join(lines[start:end]).rstrip())
    return 0


if __name__ == "__main__":
    sys.exit(main())
