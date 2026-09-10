#!/usr/bin/env python3
"""Progress overview from the spec indexes under `docs/specs/`.

Counts specs per epic, domain or status, or lists the specs behind one status.
Source of truth is the index tables, not the individual spec files. Features and
bugs live in two directories but share one number sequence, so both indexes are
read and merged.
"""

import argparse
import re
import sys
from pathlib import Path

SPEC_INDEXES = [
    Path('docs/specs/features/index.md'),
    Path('docs/specs/bugs/index.md'),
]

# Display order; anything unrecognised is appended so a typo stays visible.
STATUS_ORDER = ['Draft', 'Ready', 'In Progress', 'Done']

ROW_RE = re.compile(r'^\|(?P<cells>.+)\|\s*$')

# The File cell is a markdown link, `[042-slug.md](042-slug.md)`.
LINK_RE = re.compile(r'\[(?P<name>[^\]]+\.md)\]')


def canonical_status(raw):
    """`Draft (post-V1)` -> `Draft`; unknown values pass through unchanged."""
    for status in STATUS_ORDER:
        if raw == status or raw.startswith(status + ' '):
            return status
    return raw


def read_tickets(paths):
    """Parse the spec index tables into dicts. Raises ValueError if malformed."""
    tickets = []
    for path in paths:
        if not path.is_file():
            raise FileNotFoundError(path)

        for line in path.read_text(encoding='utf-8').splitlines():
            match = ROW_RE.match(line.strip())
            if not match:
                continue

            # maxsplit: spec 029's Summary contains escaped pipes, so only the
            # first six delimiters are structural.
            cells = [c.strip() for c in match.group('cells').split('|', 6)]
            if len(cells) < 7:
                continue

            link = LINK_RE.match(cells[0])
            if link is None:
                continue  # header, separator, or prose row

            name = link.group('name')
            tickets.append(
                {
                    'id': name.split('-', 1)[0],
                    'file': name,
                    'path': path.parent / name,
                    'type': cells[1],
                    'epic': cells[2],
                    'domain': cells[3],
                    'status': canonical_status(cells[4]),
                    'raw_status': cells[4],
                    'blocked_by': cells[5],
                    'summary': cells[6],
                }
            )

    if not tickets:
        raise ValueError('no spec rows found')

    seen = {}
    for ticket in tickets:
        if ticket['id'] in seen:
            raise ValueError(
                f"id {ticket['id']} appears twice: {seen[ticket['id']]} and {ticket['file']}"
            )
        seen[ticket['id']] = ticket['file']
    return tickets


def statuses_present(tickets):
    known = [s for s in STATUS_ORDER if any(t['status'] == s for t in tickets)]
    extra = sorted({t['status'] for t in tickets} - set(STATUS_ORDER))
    return known + extra


def print_matrix(tickets, key):
    columns = statuses_present(tickets)
    groups = {}
    for ticket in tickets:
        bucket = groups.setdefault(ticket[key], dict.fromkeys(columns, 0))
        bucket[ticket['status']] += 1

    print('\t'.join([key, 'total', *columns]))
    for name in sorted(groups):
        counts = groups[name]
        total = sum(counts.values())
        print('\t'.join([name, str(total), *[str(counts[c]) for c in columns]]))

    totals = {c: sum(g[c] for g in groups.values()) for c in columns}
    print('\t'.join(['TOTAL', str(len(tickets)), *[str(totals[c]) for c in columns]]))


def print_list(tickets, status):
    wanted = canonical_status(status)
    matches = [t for t in tickets if t['status'] == wanted]
    for ticket in sorted(matches, key=lambda t: t['id']):
        print(
            '\t'.join(
                [
                    ticket['id'],
                    ticket['epic'],
                    ticket['domain'],
                    ticket['blocked_by'],
                    ticket['summary'],
                ]
            )
        )
    return len(matches)


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog='ticket_status_count.py',
        description=(
            'Spec progress from the docs/specs indexes. Without --status it '
            'prints a group x status matrix; with --status it lists the '
            'matching specs.'
        ),
    )
    parser.add_argument(
        '--by', choices=['epic', 'domain', 'type'], default='epic',
        help='grouping for the matrix (default: epic)',
    )
    parser.add_argument(
        '--status',
        help=(
            'list tickets with this status instead of counting '
            '(Draft, Ready, In Progress, Done)'
        ),
    )
    parser.add_argument(
        '--index', nargs='+', default=[str(p) for p in SPEC_INDEXES],
        help='spec index files to read (default: the features and bugs indexes)',
    )
    args = parser.parse_args(argv)

    try:
        tickets = read_tickets([Path(p) for p in args.index])
    except FileNotFoundError as error:
        print(f'ticket_status_count: not found: {error}', file=sys.stderr)
        return 1
    except ValueError as error:
        print(f'ticket_status_count: {error}', file=sys.stderr)
        return 2

    if args.status:
        if print_list(tickets, args.status) == 0:
            print(
                f'ticket_status_count: no tickets with status {args.status!r}',
                file=sys.stderr,
            )
            return 3
        return 0

    print_matrix(tickets, args.by)
    return 0


if __name__ == '__main__':
    sys.exit(main())
