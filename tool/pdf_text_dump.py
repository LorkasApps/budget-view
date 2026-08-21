#!/usr/bin/env python3
"""Dump a PDF's text-showing operators with their coordinates (stdlib only).

Exists because the agent cannot run Dart: designing a layout parser needs to see
what the text layer actually contains, and `ing_geometry_dump_test.dart` — the
Dart equivalent — needs Flutter. Covers the subset Chrome and Syncfusion produce:
Flate-compressed content streams, `Tm`/`Td`/`TD`/`T*` positioning, `Tj`/`TJ`
strings, and `ToUnicode` CMaps for subset fonts.

Not a general PDF reader. When it cannot decode something it says so rather than
guessing.
"""

import argparse
import re
import sys
import zlib
from pathlib import Path

STREAM = re.compile(rb'<<(?P<dict>.*?)>>\s*stream\r?\n(?P<data>.*?)endstream', re.S)
BFCHAR = re.compile(rb'beginbfchar(.*?)endbfchar', re.S)
BFRANGE = re.compile(rb'beginbfrange(.*?)endbfrange', re.S)
HEXPAIR = re.compile(rb'<([0-9A-Fa-f]+)>')


def inflate_streams(raw):
    out = []
    for match in STREAM.finditer(raw):
        data = match.group('data')
        if b'FlateDecode' in match.group('dict'):
            try:
                data = zlib.decompress(data)
            except zlib.error:
                continue
        out.append(data)
    return out


def parse_tounicode(streams):
    """Merge every ToUnicode CMap found: glyph code -> unicode string."""
    mapping = {}
    for stream in streams:
        for block in BFCHAR.findall(stream):
            codes = HEXPAIR.findall(block)
            for src, dst in zip(codes[::2], codes[1::2]):
                mapping[int(src, 16)] = bytes.fromhex(dst.decode()).decode('utf-16-be', 'replace')
        for block in BFRANGE.findall(stream):
            codes = HEXPAIR.findall(block)
            for low, high, dst in zip(codes[::3], codes[1::3], codes[2::3]):
                start = int(low, 16)
                end = int(high, 16)
                base = int(dst, 16)
                for offset in range(end - start + 1):
                    mapping[start + offset] = chr(base + offset)
    return mapping


def decode_string(token, cmap):
    if token.startswith(b'<'):
        digits = token[1:-1]
        codes = [int(digits[i:i + 4], 16) for i in range(0, len(digits) - 3, 4)]
        if cmap:
            return ''.join(cmap.get(code, '�') for code in codes)
        return ''.join(chr(code) for code in codes)
    body = token[1:-1]
    body = re.sub(rb'\\([nrtbf()\\])', lambda m: m.group(1), body)
    text = body.decode('latin-1')
    if cmap and all(ord(ch) < 256 for ch in text):
        mapped = ''.join(cmap.get(ord(ch), ch) for ch in text)
        if mapped != text:
            return mapped
    return text


TOKEN = re.compile(
    rb'(?P<str>\((?:\\.|[^\\()])*\)|<[0-9A-Fa-f\s]+>)'
    rb'|(?P<num>-?\d+\.?\d*)'
    rb'|(?P<op>[A-Za-z\'"*]+)'
)


def dump(content, cmap):
    """Yields (x, y, text) in the order the page draws them."""
    x = y = 0.0
    stack = []
    pending = []
    for match in TOKEN.finditer(content):
        if match.group('str'):
            stack.append(('str', match.group('str')))
        elif match.group('num'):
            stack.append(('num', float(match.group('num'))))
        else:
            op = match.group('op').decode()
            numbers = [value for kind, value in stack if kind == 'num']
            strings = [value for kind, value in stack if kind == 'str']
            if op == 'Tm' and len(numbers) >= 6:
                x, y = numbers[4], numbers[5]
            elif op in ('Td', 'TD') and len(numbers) >= 2:
                x += numbers[0]
                y += numbers[1]
            elif op == 'T*':
                y -= 12
            elif op in ('Tj', 'TJ', "'", '"'):
                text = ''.join(decode_string(s, cmap) for s in strings)
                if text.strip():
                    pending.append((round(x, 1), round(y, 1), text))
            stack = []
    return pending


MONEY = re.compile(r'^(\d{1,3}(?:[.,]\d{3})*|\d+)[.,](\d{2})$')
SKIP_PREFIXES = (
    'summe', 'gesamt', 'total', 'zwischensumme', 'mwst', 'ust', 'netto', 'brutto',
    'du sparst', 'eingereichtes', 'tüten', 'flaschen', 'lieferadresse', 'kundenservice',
)
TOTAL_PREFIXES = ('gesamt', 'summe', 'total')


def join_fragments(items, gap=6.0, band=4.0):
    """Chrome splits words and numbers; glue neighbours on the same baseline."""
    items = sorted(items, key=lambda i: (-i[1], i[0]))
    out = []
    for x, y, text in items:
        if out:
            px, py, ptext = out[-1]
            if abs(py - y) <= band and 0 <= x - px <= gap + 6 * len(ptext):
                out[-1] = (px, py, ptext + text)
                continue
        out.append((x, y, text))
    return out


def cluster_blocks(items, tolerance=20.0):
    """One item is a block spanning ~20 units; the gap to the next is far larger."""
    blocks = []
    for x, y, text in sorted(items, key=lambda i: -i[1]):
        if blocks and abs(blocks[-1][0][1] - y) <= tolerance:
            blocks[-1].append((x, y, text))
        else:
            blocks.append([(x, y, text)])
    return blocks


def block_items(blocks, price_column_x):
    """Applies the intended parser rules and yields (description, cents)."""
    for block in blocks:
        prices = [
            (x, y, text) for x, y, text in block
            if x >= price_column_x and MONEY.match(text.replace('€', '').strip())
        ]
        words = [t for _, _, t in sorted(block, key=lambda i: i[0]) if (_, _, t) not in prices]
        label = ' '.join(text for x, y, text in sorted(block, key=lambda i: (i[0]))
                         if x < price_column_x).strip()
        if not prices:
            yield (label, None, 'no amount -> dropped')
            continue
        # Bottom-most price wins: a struck-through original sits above the real one.
        x, y, text = min(prices, key=lambda p: p[1])
        match = MONEY.match(text.replace('€', '').strip())
        cents = int(match.group(1).replace('.', '').replace(',', '')) * 100 + int(match.group(2))
        lowered = label.lower()
        if any(lowered.startswith(p) for p in TOTAL_PREFIXES):
            yield (label, cents, 'TOTAL')
        elif any(lowered.startswith(p) for p in SKIP_PREFIXES):
            yield (label, cents, 'skipped')
        else:
            yield (label, cents, 'item')


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('pdf', type=Path)
    ap.add_argument('--sort', action='store_true',
                    help='sort by y descending then x, i.e. reading order')
    ap.add_argument('--items', action='store_true',
                    help='apply the receipt parser rules and print the resulting positions')
    ap.add_argument('--price-column', type=float, default=500.0,
                    help='x from which a money token counts as the price column')
    args = ap.parse_args()

    raw = args.pdf.read_bytes()
    streams = inflate_streams(raw)
    if not streams:
        print('no decodable streams — the file may use an unsupported filter')
        return 2

    cmap = parse_tounicode(streams)
    items = []
    for stream in streams:
        if b'Tj' in stream or b'TJ' in stream:
            items += dump(stream, cmap)

    if args.items:
        joined = join_fragments(items)
        blocks = cluster_blocks(joined)
        print('# %d text items -> %d words -> %d blocks' %
              (len(items), len(joined), len(blocks)))
        for label, cents, verdict in block_items(blocks, args.price_column):
            amount = '        ' if cents is None else '%8.2f' % (cents / 100)
            print('%-9s %s  %s' % (verdict, amount, label[:70]))
        return 0

    if args.sort:
        items.sort(key=lambda item: (-item[1], item[0]))

    print('# %d text items, ToUnicode entries: %d' % (len(items), len(cmap)))
    for x, y, text in items:
        print('%8.1f %8.1f  %s' % (x, y, text))
    return 0


if __name__ == '__main__':
    sys.exit(main())
