#!/usr/bin/env python3
"""Extract a single section from a doc under docs/ by heading."""

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
# Searched in order, so a bare filename resolves without naming its directory.
# Specs come last: a spec is usually read whole, a reference page rarely is.
SEARCH_ROOTS = [
    REPO / "docs" / "development" / "reference",
    REPO / "docs" / "development" / "adr",
    REPO / "docs" / "operations" / "troubleshooting",
    REPO / "docs" / "specs" / "features",
    REPO / "docs" / "specs" / "bugs",
    REPO / "docs",
]
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*$")


def resolve(name):
    """A full path wins; otherwise the first search root that holds the name."""
    direct = Path(name)
    if direct.is_file():
        return direct
    for root in SEARCH_ROOTS:
        candidate = root / name
        if candidate.is_file():
            return candidate
    return None


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
        epilog="Example: ./.claude/helper/doc_section.py import.md 'Merchant extraction'",
    )
    p.add_argument(
        "file",
        help="bare filename, resolved against the docs/ subdirectories, or a full path",
    )
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

    path = resolve(args.file)
    if path is None:
        roots = ", ".join(str(r.relative_to(REPO)) for r in SEARCH_ROOTS)
        print(f"file not found: {args.file} (searched {roots})", file=sys.stderr)
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
