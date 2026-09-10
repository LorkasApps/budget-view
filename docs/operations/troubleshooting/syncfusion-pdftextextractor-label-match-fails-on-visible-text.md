---
title: Syncfusion PdfTextExtractor label match fails although the text is visible
date: 2026-09-10
tags:
  - troubleshooting
description: PdfTextExtractor drops parentheses and pads TextWord.text with spaces, so a naive label match fails against visible PDF text.
---

# Syncfusion PdfTextExtractor label match fails although the text is visible

## Symptom

Syncfusion text extraction: label match fails although the text is visible in the PDF.

## Impact

Parsing for the affected statement/receipt layout fails silently at the matching step, even though
the source document contains the expected label.

## Likely cause

`PdfTextExtractor` drops parentheses (`Betrag (EUR)` → `Betrag EUR`) and pads `TextWord.text` with
spaces.

## Diagnosis

Not established. The source note recorded only the symptom, the cause and the fix.

## Fix

Match bare words and `trim()` every word before comparing or joining.

## Prevention

Always `trim()` every extracted `TextWord.text` before comparing or joining it, since padding is a
known artifact of `PdfTextExtractor` — this prevents the same silent match failure in any future
label comparison.

## Escalation

No owner or on-call for this single-developer project. Reproduce against the dump harness for the
affected statement/receipt layout and inspect the raw `TextWord.text` values for padding or
stripped parentheses before matching.
