---
title: Isar collection getter isn't defined for the type Isar
date: 2026-09-10
tags:
  - troubleshooting
description: An Isar collection getter isn't defined because its extension lives in the entity's generated .g.dart, which importing a repository or isar_provider.dart does not pull into scope.
---

# Isar collection getter isn't defined for the type Isar

## Symptom

`The getter 'transactions' / 'lineItems' / 'categorys' / 'accounts' isn't defined for the type
'Isar'`.

## Impact

Fails to compile any file that calls the collection getter without the right import, blocking
`make check`.

## Likely cause

The collection getters are extensions generated into the entity's `.g.dart`, which is a `part of`
the entity library. A file that only imports a repository or `isar_provider.dart` never pulls that
extension into scope.

## Diagnosis

Check whether the file calling `isar.<collection>` also imports the entity library directly, not
just a repository or `isar_provider.dart` — the generated extension only comes into scope through
that direct import.

## Fix

Import the entity library itself for every collection touched (`../../transaction/data/transaction.dart`
for `isar.transactions`, …). Note the Isar pluralization: `Category` → **`categorys`**.

## Prevention

Import the entity library itself for every collection a file touches, rather than relying on a
repository or `isar_provider.dart` import to bring the extension into scope — this avoids the
missing-getter error recurring in new files.

## Escalation

No owner or on-call for this single-developer project. Reproduce with `make check`; if the getter
error names a collection, add a direct import of that entity's library and re-run.
