#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成 App 图标（1024x1024 PNG），纯标准库实现，无第三方依赖。
设计：暖色渐变背景 + 白色圆角卡片 + 橙色标题条 + 3x3 日历格子。
"""
import math
import os
import struct
import zlib

N = 1024

# ---------- 颜色 ----------
BG_TOP    = (255, 209, 102)
BG_BOTTOM = (255, 140, 105)
WHITE     = (255, 255, 255)
ACCENT    = (255, 140, 66)
CELL      = (233, 237, 243)


def clamp(v, lo, hi):
    return lo if v < lo else (hi if v > hi else v)


def mix(a, b, t):
    if t <= 0:
        return a
    if t >= 1:
        return b
    return (a[0] + (b[0] - a[0]) * t,
            a[1] + (b[1] - a[1]) * t,
            a[2] + (b[2] - a[2]) * t)


def rrect_sdf(px, py, cx, cy, hw, hh, r):
    qx = abs(px - cx) - (hw - r)
    qy = abs(py - cy) - (hh - r)
    ax = qx if qx > 0 else 0.0
    ay = qy if qy > 0 else 0.0
    return math.hypot(ax, ay) + min(max(qx, qy), 0.0) - r


# 卡片
CARD_CX, CARD_CY, CARD_HW, CARD_HH, CARD_R = 512.0, 512.0, 310.0, 330.0, 72.0
# 标题条
HEAD_CX, HEAD_CY, HEAD_HW, HEAD_HH = 512.0, 261.0, 310.0, 79.0
# 日历格子 3x3
GX0, GY0, STEP, HALF, SR = 288, 367, 164, 60, 26
HIGHLIGHT = {(1, 1), (2, 0)}

GRID_XMIN, GRID_XMAX = GX0, GX0 + 2 * STEP + 2 * HALF
GRID_YMIN, GRID_YMAX = GY0, GY0 + 2 * STEP + 2 * HALF


def build_rows():
    rows = []
    for y in range(N):
        ty = y / (N - 1)
        base = mix(BG_TOP, BG_BOTTOM, ty)
        row = bytearray()
        for x in range(N):
            r, g, b = base

            # 卡片（同时用它算柔和投影）
            d = rrect_sdf(x + 0.5, y + 0.5, CARD_CX, CARD_CY, CARD_HW, CARD_HH, CARD_R)

            if d > 0:
                sh = clamp(1.0 - d / 50.0, 0.0, 1.0) * 0.20
                r *= (1 - sh); g *= (1 - sh); b *= (1 - sh)

            card_cov = clamp(0.5 - d, 0.0, 1.0)
            if card_cov > 0:
                r, g, b = mix((r, g, b), WHITE, card_cov)

                # 标题条（靠卡片裁剪出圆角）
                if x <= 822 and y <= 340:
                    hd = rrect_sdf(x + 0.5, y + 0.5, HEAD_CX, HEAD_CY, HEAD_HW, HEAD_HH, 0.0)
                    hcov = clamp(0.5 - hd, 0.0, 1.0) * card_cov
                    if hcov > 0:
                        r, g, b = mix((r, g, b), ACCENT, hcov)

                # 日历格子
                if GRID_XMIN <= x <= GRID_XMAX and GRID_YMIN <= y <= GRID_YMAX:
                    col = (x - GX0) // STEP
                    rowi = (y - GY0) // STEP
                    if 0 <= col < 3 and 0 <= rowi < 3:
                        cx = GX0 + HALF + col * STEP
                        cy = GY0 + HALF + rowi * STEP
                        cd = rrect_sdf(x + 0.5, y + 0.5, cx, cy, HALF, HALF, SR)
                        ccov = clamp(0.5 - cd, 0.0, 1.0)
                        if ccov > 0:
                            color = ACCENT if (rowi, col) in HIGHLIGHT else CELL
                            r, g, b = mix((r, g, b), color, ccov)

            row.append(int(clamp(r, 0, 255)))
            row.append(int(clamp(g, 0, 255)))
            row.append(int(clamp(b, 0, 255)))
        rows.append(bytes(row))
    return rows


def write_png(path, rows):
    raw = bytearray()
    for r in rows:
        raw.append(0)
        raw += r

    def chunk(typ, data):
        c = struct.pack(">I", len(data)) + typ + data
        c += struct.pack(">I", zlib.crc32(typ + data) & 0xFFFFFFFF)
        return c

    ihdr = struct.pack(">IIBBBBB", N, N, 8, 2, 0, 0, 0)
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", ihdr)
           + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
           + chunk(b"IEND", b""))
    with open(path, "wb") as f:
        f.write(png)


if __name__ == "__main__":
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "DailyLog", "Assets.xcassets",
                       "AppIcon.appiconset", "icon-1024.png")
    out = os.path.normpath(out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    write_png(out, build_rows())
    print("icon written:", out, os.path.getsize(out), "bytes")
