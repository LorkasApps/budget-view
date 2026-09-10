---
title: ambiguous_import on Category from flutter/foundation
date: 2026-09-10
tags:
  - troubleshooting
description: ambiguous_import on an entity named Category, plus cascading phantom analyzer errors, because flutter/foundation.dart exports its own Category annotation.
---

# ambiguous_import on Category from flutter/foundation

## Symptom

`ambiguous_import` on an entity named `Category`, plus a cascade of bogus "receiver can be null"
errors in files that merely use it.

## Impact

The analyzer reports errors across many downstream files that never touch the import itself, which
can mislead a fix attempt toward the wrong files and blocks `make check`.

## Likely cause

`package:flutter/foundation.dart` exports its own `Category` annotation. Once the defining file
fails to resolve, every downstream type becomes unknown and the analyzer reports nonsense
elsewhere.

## Diagnosis

When many "receiver can be null" errors appear across files that merely use a type, check the
file that *defines* that type first for an unresolved import collision, then re-run `flutter
analyze` — downstream errors are often phantoms that disappear once the defining file resolves.

## Fix

`import 'package:flutter/foundation.dart' show immutable;`. General rule: always fix resolution
errors in the defining file first, then re-run.

## Prevention

Scope imports narrowly (e.g. `show immutable`) instead of importing all of
`flutter/foundation.dart`, to avoid future name collisions with entity types like `Category`.

## Escalation

No owner or on-call for this single-developer project. Reproduce with `make check`; if the error
list spans many files, fix the defining file's import first and re-run before touching any
downstream file.
