#!/usr/bin/env python3
"""Progress overview from `.claude/tickets/README.md`.

Counts tickets per epic, domain or status, or lists the tickets behind one
status. Source of truth is the README table, not the individual ticket files.
"""

import argparse
import re
import sys
from pathlib import Path

TICKETS_README = Path('.claude/tickets/README.md')

# Display order; anything unrecognised is appended so a typo stays visible.
STATUS_ORDER = ['Draft', 'Ready', 'In Progress', 'Done']

ROW_RE = re.compile(r'^\|(?P<cells>.+)\|\s*$')


def canonical_status(raw):
    """`Draft (post-V1)` -> `Draft`; unknown values pass through unchanged."""
    for status in STATUS_ORDER:
        if raw == status or raw.startswith(status + ' '):
            return status
    return raw


def read_tickets(path):
    """Parse the tickets README table into dicts. Raises ValueError if malformed."""
    if not path.is_file():
        raise FileNotFoundError(path)

    tickets = []
    for line in path.read_text(encoding='utf-8').splitlines():
        match = ROW_RE.match(line.strip())
        if not match:
            continue

        cells = [cell.strip() for cell in match.group('cells').split('|')]
        if len(cells) < 7:
            continue
        if not cells[0].endswith('.md'):
            continue  # header or separator row

        identifier = cells[0].split('-', 1)[0]
        tickets.append(
            {
                'id': identifier,
                'file': cells[0],
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
        raise ValueError('no ticket rows found')
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
            'Ticket progress from .claude/tickets/README.md. Without --status '
            'it prints a group x status matrix; with --status it lists the '
            'matching tickets.'
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
        '--file', default=str(TICKETS_README),
        help='path to the tickets README (default: .claude/tickets/README.md)',
    )
    args = parser.parse_args(argv)

    try:
        tickets = read_tickets(Path(args.file))
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
