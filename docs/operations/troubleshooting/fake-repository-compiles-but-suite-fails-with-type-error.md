---
title: Fake repository compiles but the suite fails with a type error
date: 2026-09-10
tags:
  - troubleshooting
description: A fake repository compiles in the editor but the suite fails with a type error because its method signature differs from the real repository it implements.
---

# Fake repository compiles but the suite fails with a type error

## Symptom

A fake repository compiles in the editor but the suite fails with a type error.

## Impact

Fails the test suite at run time with a type error that looks like a test bug, even though the
editor showed no problem.

## Likely cause

The fake `implements` a concrete repository whose method signature differs from what was assumed
— e.g. `findByHash` returns `Future<List<ImportedSource>>`, not `Future<ImportedSource?>`.
`flutter analyze` reports it, but only after the test file is part of the run.

## Diagnosis

Run `flutter analyze` with the test file included in the run — the analyzer names the offending
method once the fake is actually referenced, even though the editor showed no problem in
isolation.

## Fix

Read the repository before writing the fake, and match every signature; the analyzer message names
the offending method.

## Prevention

Read the repository before writing the fake, and match every signature up front — this prevents
the type mismatch rather than debugging it after the suite fails.

## Escalation

No owner or on-call for this single-developer project. Reproduce with
`make test-file FILE=<path>`; read the analyzer's method name and compare it against the real
repository's signature.
