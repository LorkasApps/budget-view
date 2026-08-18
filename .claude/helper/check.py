#!/usr/bin/env python3
"""Run `make check`, keep the full output on disk, print only the failures.

Exists because the agent's `$TMPDIR` is not the shell's: a log teed to
`$TMPDIR/check.log` by hand lands where the agent cannot read it. The path here
is fixed and inside the repo, so both sides always mean the same file.
"""

import argparse
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
LOG = REPO / ".claude" / "tmp" / "check.log"
SUMMARY = REPO / ".claude" / "helper" / "test_summary.py"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run a make target, tee its output to .claude/tmp/check.log "
        "and print only the failures.",
    )
    parser.add_argument(
        "target",
        nargs="?",
        default="check",
        help="make target to run (default: check)",
    )
    parser.add_argument(
        "--context",
        type=int,
        default=3,
        help="lines of context per failure, passed to test_summary.py",
    )
    args = parser.parse_args()

    LOG.parent.mkdir(parents=True, exist_ok=True)
    run = subprocess.run(
        ["make", args.target],
        cwd=REPO,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    LOG.write_text(run.stdout)

    summary = subprocess.run(
        [sys.executable, str(SUMMARY), "--context", str(args.context)],
        input=run.stdout,
        text=True,
    )
    print(f"\nfull log: {LOG.relative_to(REPO)}")
    return summary.returncode or run.returncode


if __name__ == "__main__":
    sys.exit(main())
