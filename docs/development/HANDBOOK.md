---
title: Developer Handbook
date: 2026-09-10
description: Setup, the local development loop, the gate before a commit, and the checks only a real device can make.
---

# Developer Handbook

BudgetView is a local-first budget app: Flutter/Dart, **Android only**, Isar for storage, Riverpod
for state. Code sits feature-first under `lib/features/<domain>/{data,domain,presentation}`.

Every command below comes from the `Makefile`. `make help` prints the full list; this page covers
the ones a contributor needs in order.

## Setup

```bash
make get       # resolve dependencies
make gen       # generate the Isar *.g.dart files — required before the first run
make doctor    # Flutter environment diagnostics if something looks wrong
make devices   # list connected devices and emulators
```

`make gen` is not optional on a fresh checkout: the Isar collection getters live in generated
`*.g.dart` files, which are not committed. It is also required after **every** schema change,
including appending a value to an existing `@enumerated` enum — see
[appended-enum-value-reads-back-as-first-value-in-isar.md](../operations/troubleshooting/appended-enum-value-reads-back-as-first-value-in-isar.md).

## The local loop

```bash
make run             # debug build on the default device
make run-release     # release build on the default device
make gen-watch       # regenerate on change while working on an entity
make format          # format all Dart code
```

Narrow the test run while iterating:

```bash
make test-name NAME="dedupe"                     # tests whose NAME matches — not a path
make test-file FILE=test/features/.../foo_test.dart
```

`test-name` matches the **test name**, `test-file` takes a path. Mixing them up is the usual reason
a run reports zero tests.

## The gate

```bash
make check         # analyze + test. Run this before every commit
make pre-commit    # format-check + analyze + test, the full gate
make release-check # check + APK. R8 runs nowhere else
```

`make check` is the minimum before a commit. Note that `flutter analyze` exits non-zero on `info`
severity too, so an unused import fails the gate — see
[flutter-analyze-fails-on-info-severity-findings.md](../operations/troubleshooting/flutter-analyze-fails-on-info-severity-findings.md).

Read a failed run through the helper rather than by hand:

```bash
./.claude/helper/check.py          # keeps the full output at .claude/tmp/check.log
```

`make release-check` proves the release build **completes**. It does not prove the app works: R8
only runs in the release build, and it has broken OCR at runtime while the build stayed green. A
release APK needs OCR verified on a device — see
[release-apk-ocr-fails-r8-strips-ml-kit-classes.md](../operations/troubleshooting/release-apk-ocr-fails-r8-strips-ml-kit-classes.md).

## What automation cannot check

Some acceptance criteria can only be closed by a person holding the phone. A spec that carries them
stays `In Progress` until they are run.

| Not checkable by `make check` | Why |
|-------------------------------|-----|
| Rendering, layout width, gesture behaviour | The widget test surface is `800x600` and lazily built lists do not build off-screen children |
| Real OCR | ML Kit has no test-VM binding, so layout rules are tested against dumped coordinates instead |
| Release-build behaviour | R8 runs only there, and renaming breaks reflective lookups |
| Anything touching Isar inside `testWidgets` | Isar I/O never completes in the fake-async widget zone |

For a parser, the evidence is a real statement: run the env-gated harness in `test/tool/` with
`ING_PDF=/path/statement.pdf` and derive rules from the dump, never from reading the PDF. The
document itself never enters the repository.

## Documentation duties

Before writing code, read [../index.md](../index.md), then the relevant page under
[reference/](reference/index.md) and the [ADR index](adr/index.md). Docs are cheap, source is not.

After code lands:

- update the reference page for the feature in the same change
- record an architectural choice as a new ADR, with an Evidence section citing `file:line`
- turn a symptom you had to diagnose into a page under
  [troubleshooting/](../operations/troubleshooting/index.md)
- tick the acceptance criteria in the spec and only then set it `Done`

## Conventions

- Commits are `type: subject` — no scope in parentheses, no AI attribution
- Money is int64 cents. "Not set" is `null` everywhere, never an empty-string sentinel
- Cross-cutting services are an interface plus a `Local` implementation, so widget tests can fake
  them without touching Isar
- Never write Dart through a shell heredoc: zsh escapes `\!` and the analyzer blames the wrong line
