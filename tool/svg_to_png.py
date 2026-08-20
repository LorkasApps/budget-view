#!/usr/bin/env python3
"""Rasterise the launcher-icon SVGs in assets/icon to PNG (stdlib only).

Deliberately covers only the subset those files use: an optional opaque <rect>
plus one filled <path> of M/L/C/Z segments inside a translate/scale group.
Anything else raises instead of rendering something subtly wrong.
"""

import argparse
import re
import struct
import sys
import zlib
from array import array
from pathlib import Path

IDENTITY = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)


def multiply(m, t):
    a, b, c, d, e, f = m
    ta, tb, tc, td, te, tf = t
    return (
        a * ta + c * tb,
        b * ta + d * tb,
        a * tc + c * td,
        b * tc + d * td,
        a * te + c * tf + e,
        b * te + d * tf + f,
    )


def parse_transform(text):
    matrix = IDENTITY
    for name, args in re.findall(r'(translate|scale|matrix)\s*\(([^)]*)\)', text or ''):
        v = [float(x) for x in re.findall(r'-?\d+\.?\d*(?:e-?\d+)?', args)]
        if name == 'translate':
            t = (1.0, 0.0, 0.0, 1.0, v[0], v[1] if len(v) > 1 else 0.0)
        elif name == 'scale':
            sx = v[0]
            t = (sx, 0.0, 0.0, v[1] if len(v) > 1 else sx, 0.0, 0.0)
        else:
            t = tuple(v)
        matrix = multiply(matrix, t)
    return matrix


def apply(m, x, y):
    a, b, c, d, e, f = m
    return a * x + c * y + e, b * x + d * y + f


def flatten(d, steps):
    """Path data to polylines. Absolute M/L/C/Z only, which is what we author."""
    polys, pts, cur, start = [], [], (0.0, 0.0), (0.0, 0.0)
    for cmd, args in re.findall(r'([A-Za-z])([^A-Za-z]*)', d):
        v = [float(x) for x in re.findall(r'-?\d+\.?\d*(?:e-?\d+)?', args)]
        if cmd == 'M':
            if len(pts) > 1:
                polys.append(pts)
            cur = start = (v[0], v[1])
            pts = [cur]
            for i in range(2, len(v), 2):
                cur = (v[i], v[i + 1])
                pts.append(cur)
        elif cmd == 'L':
            for i in range(0, len(v), 2):
                cur = (v[i], v[i + 1])
                pts.append(cur)
        elif cmd == 'C':
            for i in range(0, len(v), 6):
                p0 = cur
                p1, p2, p3 = (v[i], v[i + 1]), (v[i + 2], v[i + 3]), (v[i + 4], v[i + 5])
                for k in range(1, steps + 1):
                    t = k / steps
                    u = 1.0 - t
                    pts.append((
                        u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0],
                        u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1],
                    ))
                cur = p3
        elif cmd in 'Zz':
            pts.append(start)
            polys.append(pts)
            pts, cur = [], start
        else:
            raise SystemExit('svg_to_png: unsupported path command %r' % cmd)
    if len(pts) > 1:
        polys.append(pts)
    return polys


def coverage(polys, w, h, subsamples):
    """Even-odd scanline fill. Vertical AA by subsampling, horizontal AA analytic."""
    edges = []
    for poly in polys:
        for (x1, y1), (x2, y2) in zip(poly, poly[1:]):
            if y1 != y2:
                edges.append((x1, y1, x2, y2, (x2 - x1) / (y2 - y1)))
    cov = array('f', bytes(4 * w * h))
    weight = 1.0 / subsamples
    for row in range(h):
        base = row * w
        for s in range(subsamples):
            y = row + (s + 0.5) / subsamples
            xs = sorted(x1 + (y - y1) * slope
                        for x1, y1, x2, y2, slope in edges
                        if (y1 > y) is not (y2 > y))
            for i in range(0, len(xs) - 1, 2):
                xa, xb = max(0.0, xs[i]), min(float(w), xs[i + 1])
                if xb <= xa:
                    continue
                ia, ib = int(xa), min(int(xb), w - 1)
                if ia == ib:
                    cov[base + ia] += (xb - xa) * weight
                    continue
                cov[base + ia] += (ia + 1 - xa) * weight
                for px in range(ia + 1, ib):
                    cov[base + px] += weight
                cov[base + ib] += (xb - ib) * weight
    return cov


def write_png(path, w, h, pixels):
    rows = [b'\x00' + pixels[y * w * 4:(y + 1) * w * 4].tobytes() for y in range(h)]
    def chunk(tag, data):
        return (struct.pack('>I', len(data)) + tag + data
                + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF))
    path.write_bytes(
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
        + chunk(b'IDAT', zlib.compress(b''.join(rows), 9))
        + chunk(b'IEND', b'')
    )


def parse_color(text):
    text = text.strip().lstrip('#')
    if len(text) != 6:
        raise SystemExit('svg_to_png: only #rrggbb fills are supported, got %r' % text)
    return tuple(int(text[i:i + 2], 16) for i in (0, 2, 4))


def render(svg_path, png_path, size, steps, subsamples):
    svg = svg_path.read_text()
    view = re.search(r'viewBox="([\d.\s-]+)"', svg)
    if not view:
        raise SystemExit('svg_to_png: %s has no viewBox' % svg_path)
    vx, vy, vw, vh = [float(x) for x in view.group(1).split()]
    unit = multiply((size / vw, 0.0, 0.0, size / vh, 0.0, 0.0),
                    (1.0, 0.0, 0.0, 1.0, -vx, -vy))

    pixels = array('B', bytes(4 * size * size))
    rect = re.search(r'<rect[^>]*fill="([^"]+)"', svg)
    if rect:
        r, g, b = parse_color(rect.group(1))
        pixels = array('B', bytes([r, g, b, 255]) * (size * size))

    groups = re.findall(r'<g[^>]*transform="([^"]*)"[^>]*>(.*?)</g>', svg, re.S)
    bodies = groups or [('', svg)]
    for transform, body in bodies:
        matrix = multiply(unit, parse_transform(transform))
        for fill, d in re.findall(r'<path[^>]*fill="([^"]+)"[^>]*\sd="([^"]+)"', body):
            r, g, b = parse_color(fill)
            polys = [[apply(matrix, x, y) for x, y in poly] for poly in flatten(d, steps)]
            cov = coverage(polys, size, size, subsamples)
            for i in range(size * size):
                alpha = cov[i]
                if alpha <= 0.0:
                    continue
                alpha = 1.0 if alpha > 1.0 else alpha
                o = i * 4
                inv = 1.0 - alpha
                out_a = alpha + pixels[o + 3] / 255.0 * inv
                pixels[o] = int(r * alpha + pixels[o] * inv + 0.5)
                pixels[o + 1] = int(g * alpha + pixels[o + 1] * inv + 0.5)
                pixels[o + 2] = int(b * alpha + pixels[o + 2] * inv + 0.5)
                pixels[o + 3] = int(out_a * 255 + 0.5)

    write_png(png_path, size, size, pixels)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('svg', nargs='+', type=Path, help='SVG files; each is written as a sibling .png')
    ap.add_argument('--size', type=int, default=1024, help='output edge length in px (default 1024)')
    ap.add_argument('--steps', type=int, default=48, help='line segments per bezier (default 48)')
    ap.add_argument('--subsamples', type=int, default=8, help='scanlines per pixel row (default 8)')
    args = ap.parse_args()

    for svg_path in args.svg:
        png_path = svg_path.with_suffix('.png')
        render(svg_path, png_path, args.size, args.steps, args.subsamples)
        print('%s\t%d bytes' % (png_path, png_path.stat().st_size))
    return 0


if __name__ == '__main__':
    sys.exit(main())
