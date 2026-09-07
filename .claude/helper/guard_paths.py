#!/usr/bin/env python3
"""PreToolUse guard: reject sensitive or oversized file loads.

Backstop for `permissions.deny` in .claude/settings.json. Deny rules match the
path as written; this hook also resolves it and weighs the file, so a relative
path or an unexpectedly huge file cannot slip through. It covers `Bash` readers
too, which path-based permission rules never see.

Inspects paths and file sizes only — never file contents.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys

DENY = "deny"
ASK = "ask"

SECRETS: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"(^|/)\.env(\.|$)"), "an environment file"),
    (re.compile(r"(^|/)secrets?/"), "a secrets directory"),
    (re.compile(r"\.(pem|jks|keystore|p12|pfx|der)$"), "a key or certificate"),
    (re.compile(r"(^|/)key\.properties$"), "the Android signing config"),
    (re.compile(r"(^|/)id_(rsa|dsa|ecdsa|ed25519)$"), "an SSH private key"),
    (re.compile(r"(^|/)\.(npmrc|netrc)$"), "a registry or network credential"),
    (re.compile(r"(^|/)credentials(\.json)?$"), "a credentials file"),
]

BALLAST: list[tuple[re.Pattern[str], str]] = [
    (
        re.compile(
            r"(^|/)(build|dist|node_modules|vendor|coverage|\.next|\.venv"
            r"|__pycache__|\.dart_tool)/"
        ),
        "a build, dependency or coverage directory",
    ),
    (re.compile(r"\.g\.dart$"), "generated Isar code"),
    (re.compile(r"\.lock$"), "a lock file"),
    (re.compile(r"\.min\.(js|css)$|\.map$"), "a minified or source-map artifact"),
    (re.compile(r"(^|/)(libisar\.(dylib|so)|isar\.dll)$"), "a native binary"),
]

# Not blocked outright: this repo holds no fixture PDFs by decision
# (decisions.md, 2026-08-11), so a document here is real financial data — but
# handing one over deliberately is a legitimate move. Confirm, never silent.
RAW_DOCS: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"\.(pdf|heic)$"), "a raw document, so probably real bank data"),
]

# Only these leading words make a Bash command a content read worth checking.
# Scanning every token would reject `find . -name '*.pdf'`, which reads nothing.
READERS = frozenset(
    """cat head tail less more strings xxd od base64 open bat cp mv scp rsync
    nl tac shasum md5sum""".split()
)

PATH_KEYS = ("file_path", "notebook_path", "path")


def classify(path: str) -> tuple[str, str] | None:
    for pattern, what in SECRETS:
        if pattern.search(path):
            return DENY, f"{path} is {what}. Blocked before it reaches the context."
    for pattern, what in BALLAST:
        if pattern.search(path):
            return DENY, f"{path} — {what}. Nothing there belongs in the context."
    for pattern, what in RAW_DOCS:
        if pattern.search(path):
            return ASK, f"{path} is {what}. Confirm before it enters the context."
    return None


def too_big(path: str, max_bytes: int) -> tuple[str, str] | None:
    try:
        size = os.path.getsize(path)
    except OSError:
        return None
    if size <= max_bytes:
        return None
    return DENY, (
        f"{path} is {size // 1024} KB, over the {max_bytes // 1024} KB budget. "
        "Read a slice with offset/limit, or route the question through a "
        ".claude/helper script."
    )


def bash_paths(command: str) -> list[str]:
    """Arguments of reader invocations inside a shell command."""
    found: list[str] = []
    for segment in re.split(r"[;|&\n]+|\$\(|`", command):
        tokens = segment.split()
        while tokens and (
            "=" in tokens[0] or tokens[0] in {"sudo", "command", "time", "nohup"}
        ):
            tokens.pop(0)
        if tokens and os.path.basename(tokens[0]) in READERS:
            found += [t for t in tokens[1:] if not t.startswith("-")]
    return found


def candidates(payload: dict) -> list[str]:
    tool_input = payload.get("tool_input") or {}
    if payload.get("tool_name") == "Bash":
        return bash_paths(str(tool_input.get("command", "")))
    return [str(tool_input[k]) for k in PATH_KEYS if tool_input.get(k)]


def verdict(payload: dict, max_bytes: int) -> tuple[str, str] | None:
    for raw in candidates(payload):
        path = raw.strip().strip("'\"")
        if not path:
            continue
        probe = os.path.relpath(path) if os.path.isabs(path) else path
        found = classify(path) or classify(probe)
        if found:
            return found
        if payload.get("tool_name") in ("Read", "Bash"):
            found = too_big(path, max_bytes)
            if found:
                return found
    return None


def emit(decision: str, reason: str) -> None:
    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": decision,
                "permissionDecisionReason": reason,
            }
        },
        sys.stdout,
    )
    sys.stdout.write("\n")


def read_case(path: str) -> dict:
    return {"tool_name": "Read", "tool_input": {"file_path": path}}


CASES: list[tuple[dict, str | None]] = [
    (read_case(".env"), DENY),
    (read_case("secrets/token.txt"), DENY),
    (read_case("a/b.pem"), DENY),
    (read_case("android/key.properties"), DENY),
    (read_case(".npmrc"), DENY),
    (read_case("gcp/credentials.json"), DENY),
    (read_case("a/b.pfx"), DENY),
    (read_case("build/app/out.apk"), DENY),
    (read_case("coverage/lcov.info"), DENY),
    (read_case("web/app.min.js"), DENY),
    (read_case("lib/features/transaction/data/transaction.g.dart"), DENY),
    (read_case("pubspec.lock"), DENY),
    ({"tool_name": "Bash", "tool_input": {"command": "cat .env"}}, DENY),
    ({"tool_name": "Bash", "tool_input": {"command": "ls -la && head -5 secrets/k"}}, DENY),
    (read_case("auszug_januar.pdf"), ASK),
    (read_case("lib/main.dart"), None),
    (read_case(".claude/docs/README.md"), None),
    ({"tool_name": "Bash", "tool_input": {"command": "find . -name '*.pdf'"}}, None),
    ({"tool_name": "Bash", "tool_input": {"command": "flutter build apk"}}, None),
    ({"tool_name": "Bash", "tool_input": {"command": "grep -m 5 x .claude/docs/*.md"}}, None),
    ({"tool_name": "Edit", "tool_input": {"file_path": "lib/main.dart"}}, None),
]


def self_test(max_bytes: int) -> int:
    failures = 0
    for payload, want in CASES:
        found = verdict(payload, max_bytes)
        got = found[0] if found else None
        if got != want:
            failures += 1
            label = payload["tool_input"].get("file_path") or payload["tool_input"].get(
                "command"
            )
            print(f"FAIL want={want} got={got} for {label}")
    print(f"PASS: {len(CASES)} cases" if not failures else f"{failures} failed")
    return 1 if failures else 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="PreToolUse guard. Reads hook JSON on stdin; prints a deny or "
        "ask decision when the tool would load a sensitive or oversized path, "
        "otherwise prints nothing.",
        epilog="Wired into .claude/settings.json under "
        "hooks.PreToolUse[matcher=Read|Edit|Write|NotebookEdit|Bash].",
    )
    parser.add_argument(
        "--max-bytes",
        type=int,
        default=65536,
        help="reject reads of files larger than this (default: 65536)",
    )
    parser.add_argument(
        "--self-test", action="store_true", help="run the built-in cases and exit"
    )
    args = parser.parse_args()

    if args.self_test:
        return self_test(args.max_bytes)

    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0

    found = verdict(payload, args.max_bytes)
    if found:
        emit(*found)
    return 0


if __name__ == "__main__":
    sys.exit(main())
