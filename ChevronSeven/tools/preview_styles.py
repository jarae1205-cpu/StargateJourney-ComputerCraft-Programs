"""
Draws the three kinds of Chevron Seven gate front-on, from the mod's textures and the sizes
StargateRenderer uses, to check the textures without starting the game. Flat light, no
perspective, no Minecraft shaders.

    python3 tools/preview_styles.py out.png      (run from ChevronSeven/; needs Pillow and numpy)
"""
import math
import os
import sys

import numpy as np
from PIL import Image

TEX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "main", "resources", "assets", "chevron7", "textures")

R_OUT, R_MID, R_IN = 3.42, 2.94, 2.45

# the same values as StargateRenderer's looks
LOOKS = {
    "Stargate": dict(stone="gate_stone", track="gate_track", glyphs="gui/glyphs", horizon="event_horizon", symbols=39, chevrons=7,
                     glyph=(0.17, 0.16, 0.15), lit=(1.0, 0.58, 0.16), unlit=(0.42, 0.24, 0.13), housing=0.62, tint=(0.72, 0.86, 1.0)),
    "Stargate (Infinity)": dict(stone="infinity_stone", track="infinity_track", glyphs="gui/glyphs", horizon="infinity_horizon",
                                symbols=39, chevrons=7, glyph=(0.06, 0.07, 0.09), lit=(0.84, 0.95, 0.24), unlit=(0.17, 0.19, 0.24),
                                housing=0.30, tint=(1.0, 1.0, 1.0)),
    "Stargate (Stargate Network)": dict(stone="network_stone", track="network_track", glyphs="gui/letters", horizon="event_horizon",
                                        symbols=36, chevrons=9, glyph=(0.80, 0.88, 1.0), lit=(0.32, 0.70, 1.0), unlit=(0.14, 0.20, 0.30),
                                        housing=0.50, tint=(0.66, 0.84, 1.0)),
}
ORDER = {7: [1, 2, 3, 6, 7, 8, 0], 9: [1, 2, 3, 6, 7, 8, 4, 5, 0]}


def load(name):
    path = os.path.join(TEX, name if "/" in name else "entity/" + name) + ".png"
    return np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32) / 255.0


def sample(tex, u, v):
    h, w = tex.shape[:2]
    x = np.clip((np.mod(u, 1.0) * w).astype(int), 0, w - 1)
    y = np.clip((np.mod(v, 1.0) * h).astype(int), 0, h - 1)
    return tex[y, x]


def draw_gate(look, size, rot, open_):
    img = np.zeros((size, size, 3), dtype=np.float32)
    img[:] = (0.80, 0.86, 0.93)
    scale = size / 7.6
    ys, xs = np.mgrid[0:size, 0:size] + 0.5
    x = (xs - size / 2) / scale
    y = -(ys - size / 2) / scale
    r = np.hypot(x, y)
    a = np.degrees(np.arctan2(x, y)) % 360  # clockwise from the top, as the renderer turns

    def paint(mask, color):
        img[mask] = color[mask] if color.ndim == 3 else color

    # the event horizon: the renderer swirls the texture onto the disc
    if open_:
        tex = load(look["horizon"])
        rr = r / R_IN
        swirl = np.radians(a) + (1 - rr) * 0.9 * math.sin(30 * 0.03) + 30 * 0.006
        c = sample(tex, 0.5 + 0.48 * rr * np.sin(swirl), 0.5 + 0.48 * rr * np.cos(swirl))
        bright = np.minimum(1.0, 0.78 + 0.22 * (1 - rr))[..., None]
        col = c[..., :3] * np.array(look["tint"]) * bright
        alpha = 0.93 * c[..., 3:4]
        m = r < R_IN
        img[m] = (img * (1 - alpha) + col * alpha)[m]

    # the symbol track, turned by rot degrees
    step = 360.0 / look["symbols"]
    tex = load(look["track"])
    ta = (a - rot) % 360
    m = (r >= R_IN) & (r < R_MID)
    c = sample(tex, (ta / step) % 1, (R_MID - r) / (R_MID - R_IN))
    paint(m, c[..., :3])

    # the glyphs
    atlas = load(look["glyphs"])
    rc, h = (R_IN + R_MID) / 2, 0.2
    for k in range(look["symbols"]):
        ang = math.radians(k * step + rot)
        nx, ny = math.sin(ang), math.cos(ang)
        tx, ty = ny, -nx
        dx, dy = x - rc * nx, y - rc * ny
        t = dx * tx + dy * ty
        n = dx * nx + dy * ny
        m = (np.abs(t) <= h) & (np.abs(n) <= h)
        if not m.any():
            continue
        u = ((k % 8) + (t[m] + h) / (2 * h)) / 8
        v = ((k // 8) + (h - n[m]) / (2 * h)) / 5
        c = sample(atlas, u, v)
        on = c[:, 3] > 0.5
        sub = img[m]
        sub[on] = np.array(look["glyph"])
        img[m] = sub

    # the outer ring
    tex = load(look["stone"])
    m = (r >= R_MID) & (r <= R_OUT)
    c = sample(tex, (a / 10.0) % 1, (R_OUT - r) / (R_OUT - R_MID))
    paint(m, c[..., :3])

    # chevrons: a housing of ring stone, and the light on it
    lit_slots = set(ORDER[look["chevrons"]]) if open_ else set()
    vee = load("chevron")
    for slot in range(9):
        ang = math.radians(slot * 40.0)
        nx, ny = math.sin(ang), math.cos(ang)
        tx, ty = ny, -nx
        dx, dy = x - 3.18 * nx, y - 3.18 * ny
        t = dx * tx + dy * ty
        n = dx * nx + dy * ny
        top, bottom = 0.36, -0.34
        f = np.clip((top - n) / (top - bottom), 0, 1)
        half = 0.36 + (0.15 - 0.36) * f
        m = (n <= top) & (n >= bottom) & (np.abs(t) <= half)
        c = sample(tex, (t[m] + half[m]) / (2 * half[m]), f[m])
        sub = img[m]
        sub[:] = c[:, :3] * look["housing"]
        img[m] = sub
        # the light
        top, bottom, hl = 0.34, -0.32, 0.33
        m = (n <= top) & (n >= bottom) & (np.abs(t) <= hl)
        c = sample(vee, (t[m] + hl) / (2 * hl), (top - n[m]) / (top - bottom))
        on = c[:, 3] > 0.5
        colour = np.array(look["lit"] if slot in lit_slots else look["unlit"])
        sub = img[m]
        sub[on] = c[on, :3] * colour
        img[m] = sub
    return Image.fromarray(np.clip(img * 255 + 0.5, 0, 255).astype(np.uint8), "RGB")


def main(out):
    size = 520
    names = list(LOOKS)
    sheet = Image.new("RGB", (size * len(names), size), (204, 219, 237))
    for i, name in enumerate(names):
        sheet.paste(draw_gate(LOOKS[name], size, 23.0, True), (i * size, 0))
    sheet.save(out, optimize=True)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "styles.png")
