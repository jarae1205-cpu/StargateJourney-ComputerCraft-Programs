#!/usr/bin/env python3
"""Make the resources of the Infinity Stargate add-on.

    python3 tools/make_resources.py <jsg-1.20.1 jar>

Writes into src/main/resources/:
  assets/jsginfinity/textures/gate/infinity_gate.png   the ring, symbol track and chevron housings
  assets/jsginfinity/textures/gate/chevron*.png        the chevrons: unlit, lit, off
  assets/jsginfinity/textures/gate/iris_blade.png      the iris blades, which close into a spiral
  assets/jsginfinity/textures/gate/wormhole_spiral.png the whirlpool drawn over an open wormhole
  assets/jsginfinity/textures/block/*.png              the blocks you build the gate from
  assets/jsginfinity/textures/dhd/<look>/*.png         the Infinity and orange DHDs: body, keys and dome
  block states, models, names, recipes, loot tables, and JSG's block tags

The gate is drawn with Just Stargate Mod's own Milky Way models, so its
textures must line up with their UV layouts. The script reads only the
shapes and UV layouts of those models from the jar you give it; it never
reads JSG's textures. Each texel is traced back to the point of the model
it lands on, and that point's position, the direction its face looks and
the sharp edges near it decide the colour: flat cartoon colours with ink
outlines, as the gate is drawn in Stargate Infinity.
"""

import json
import math
import os
import sys
import zipfile

import numpy as np
from PIL import Image, ImageDraw

MODELS = "assets/jsg/models/tesr/"
HERE = os.path.dirname(os.path.abspath(__file__))
RESOURCES = os.path.join(HERE, "..", "src", "main", "resources")
OUT = os.path.join(RESOURCES, "assets", "jsginfinity", "textures")
MOD = "jsginfinity"
DHDS = {  # block: (name, the dye that turns JSG's Milky Way DHD into it)
    "infinity_dhd": ("Infinity DHD", "lime_dye"),
    "orange_dhd": ("Orange DHD", "orange_dye"),
}
BLOCKS = {  # block: (front texture, name, the JSG block it is made from)
    "infinity_stargate_base_block": ("infinity_stargate_base_front", "Infinity Stargate Base", "stargate_milkyway_base_block"),
    "infinity_stargate_ring_block": ("infinity_stargate_ring_front", "Infinity Stargate Ring", "stargate_milkyway_ring_block"),
    "infinity_stargate_chevron_block": ("infinity_stargate_chevron_front", "Infinity Stargate Chevron", "stargate_milkyway_chevron_block"),
}


# ---------------------------------------------------------------- models

class Model:
    def __init__(self, text):
        vs, vts, faces = [], [], []
        for line in text.splitlines():
            p = line.split()
            if not p:
                continue
            if p[0] == "v":
                vs.append([float(x) for x in p[1:4]])
            elif p[0] == "vt":
                vts.append([float(x) for x in p[1:3]])
            elif p[0] == "f":
                idx = []
                for t in p[1:]:
                    a = t.split("/")
                    idx.append((int(a[0]) - 1, int(a[1]) - 1 if len(a) > 1 and a[1] else -1))
                for k in range(1, len(idx) - 1):
                    faces.append((idx[0], idx[k], idx[k + 1]))
        self.v = np.array(vs, float)
        self.vt = np.array(vts, float) if vts else np.zeros((1, 2))
        self.faces = [f for f in faces if min(c[1] for c in f) >= 0]
        self._find_creases()

    def depth(self, fi):
        return float(self.v[[c[0] for c in self.faces[fi]]][:, 2].mean())

    def normal(self, f):
        p = self.v[[c[0] for c in f]]
        n = np.cross(p[1] - p[0], p[2] - p[0])
        ln = np.linalg.norm(n)
        return n / ln if ln > 0 else n

    def _find_creases(self, angle=38.0):
        """Mark the edges of each face that are sharp (or open) in 3D."""
        # Vertices that sit at the same spot are one vertex for this.
        key = {}
        weld = np.zeros(len(self.v), int)
        for i, p in enumerate(np.round(self.v, 4)):
            weld[i] = key.setdefault(tuple(p), len(key))
        edges = {}
        self.normals = []
        for fi, f in enumerate(self.faces):
            n = self.normal(f)
            self.normals.append(n)
            for k in range(3):
                a, b = weld[f[k][0]], weld[f[(k + 1) % 3][0]]
                edges.setdefault((min(a, b), max(a, b)), []).append(fi)
        cos_limit = math.cos(math.radians(angle))
        self.crease = [[False, False, False] for _ in self.faces]
        for fi, f in enumerate(self.faces):
            for k in range(3):
                a, b = weld[f[k][0]], weld[f[(k + 1) % 3][0]]
                users = edges[(min(a, b), max(a, b))]
                if len(users) < 2:
                    self.crease[fi][k] = True
                    continue
                for o in users:
                    # JSG's models don't wind all their faces the same way, so
                    # a face and its neighbour can point opposite ways though
                    # they lie flat together: compare them without the sign.
                    if o != fi and abs(float(np.dot(self.normals[fi], self.normals[o]))) < cos_limit:
                        self.crease[fi][k] = True
                        break


def rasterise(canvas, done, model, paint, wrap=False):
    """Paint every texel a face of the model covers.

    paint(pos, n, edge, face) gets the 3D points of the texels (N x 3), the
    face's normal, each texel's distance to the face's nearest sharp edge (in
    blocks) and the face index, and returns N x 3 colours.
    """
    h, w, _ = canvas.shape
    for fi, f in enumerate(model.faces):
        P = model.v[[c[0] for c in f]]
        uv = model.vt[[c[1] for c in f]].copy()
        if wrap:
            shift = np.floor(uv.min(0))
            uv -= shift
        px = np.stack([uv[:, 0] * w, (1.0 - uv[:, 1]) * h], 1)
        x0, y0 = np.floor(px.min(0)).astype(int)
        x1, y1 = np.ceil(px.max(0)).astype(int)
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, w - 1), min(y1, h - 1)
        if x1 < x0 or y1 < y0:
            continue
        d = (px[1, 1] - px[2, 1]) * (px[0, 0] - px[2, 0]) + (px[2, 0] - px[1, 0]) * (px[0, 1] - px[2, 1])
        if abs(d) < 1e-9:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        l0 = ((px[1, 1] - px[2, 1]) * (xs - px[2, 0]) + (px[2, 0] - px[1, 0]) * (ys - px[2, 1])) / d
        l1 = ((px[2, 1] - px[0, 1]) * (xs - px[2, 0]) + (px[0, 0] - px[2, 0]) * (ys - px[2, 1])) / d
        l2 = 1.0 - l0 - l1
        # A little past the edges, so faces meet without gaps.
        m = (l0 >= -0.03) & (l1 >= -0.03) & (l2 >= -0.03)
        if not m.any():
            continue
        L = np.stack([l0[m], l1[m], l2[m]], 1)
        pos = L @ P
        # Distance to each sharp edge: edge k runs from corner k to k+1, so it
        # faces corner k+2; the texel's distance is l[k+2] times that height.
        area2 = np.linalg.norm(np.cross(P[1] - P[0], P[2] - P[0]))
        edge = np.full(len(pos), 9.0)
        for k in range(3):
            if model.crease[fi][k]:
                ln = np.linalg.norm(P[(k + 1) % 3] - P[k])
                if ln > 0:
                    edge = np.minimum(edge, np.clip(L[:, (k + 2) % 3], 0, None) * area2 / ln)
        yy, xx = np.nonzero(m)
        canvas[yy + y0, xx + x0] = paint(pos, model.normals[fi], edge, fi)
        done[yy + y0, xx + x0] = True


def bleed(canvas, done, steps=12):
    """Spread colour past the painted islands, so filtering shows no seams."""
    img = canvas.copy()
    filled = done.copy()
    for _ in range(steps):
        acc = np.zeros_like(img, float)
        cnt = np.zeros(filled.shape, float)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh = np.roll(np.roll(img, dy, 0), dx, 1)
            sf = np.roll(np.roll(filled, dy, 0), dx, 1)
            acc += sh * sf[..., None]
            cnt += sf
        grow = (~filled) & (cnt > 0)
        img[grow] = (acc[grow] / cnt[grow][:, None])
        filled |= grow
    img[~filled] = img[filled].mean(0) if filled.any() else 0
    return img


def mix(a, b, t):
    t = np.clip(t, 0, 1)[..., None]
    return np.asarray(a, float) * (1 - t) + np.asarray(b, float) * t


# ---------------------------------------------------------------- Infinity gate

INK = (30, 32, 44)
PALE = (198, 207, 220)
LIGHT = (222, 229, 238)
MID = (158, 170, 188)
SHADE = (120, 132, 152)
SLATE = (96, 108, 132)
SLATE_DARK = (78, 88, 110)
GLYPH = (186, 197, 214)
LIME = (214, 240, 72)
LIME_HOT = (246, 255, 170)

INK_WIDTH = 0.03  # blocks
def paint_gate_texture(models, size, tint):
    gate, ring = models["gate"], models["ring"]
    frame, back = models["chevron_frame"], models["chevron_back"]
    canvas = np.zeros((size, size, 3), float)
    done = np.zeros((size, size), bool)
    tint = np.array(tint)

    def cel(pos, n, edge, base_front, base_side, base_back, front):
        if abs(n[2]) > 0.72:
            c = np.tile(np.array(base_front if front else base_back, float), (len(pos), 1))
        else:
            # Faces turned up, towards the light, a little brighter.
            up = abs(n[1]) * (1 if pos[:, 1].mean() > 0 else 0.3)
            c = mix(base_side, base_front, np.full(len(pos), 0.35 * up))
        return mix(c, INK, (edge < INK_WIDTH).astype(float))

    def paint_gate(pos, n, edge, fi):
        r = np.hypot(pos[:, 0], pos[:, 1])
        front = gate.depth(fi) > -0.12
        c = cel(pos, n, edge, PALE, MID, SHADE, front)
        # A lighter rim along the inside, like the cartoon's highlight.
        if abs(n[2]) > 0.72 and front:
            c = mix(c, LIGHT, ((r > 3.72) & (r < 3.86)).astype(float) * 0.8)
            c = mix(c, INK, (np.abs(r - 3.70) < INK_WIDTH * 0.8).astype(float))
        return c * tint

    def paint_ring(pos, n, edge, fi):
        z = ring.depth(fi)
        if abs(n[2]) < 0.5:  # walls of the glyphs and the ring's rims
            c = np.tile(np.array(INK, float), (len(pos), 1))
        elif z < 0.12:
            c = np.tile(np.array(SHADE, float), (len(pos), 1))
        elif z > 0.185:  # raised glyph tops
            c = np.tile(np.array(GLYPH, float), (len(pos), 1))
            c = mix(c, INK, (edge < INK_WIDTH * 0.6).astype(float))
        else:
            # The track the glyphs stand on. Its texels are shared with the
            # gate's outer rim and the chevron housings, so it gets one even
            # slate colour that suits all three: no lines of its own.
            c = np.tile(np.array(SLATE, float), (len(pos), 1))
        return c * tint

    def paint_frame(pos, n, edge, fi):
        # The housings the chevrons sit in: dark slate, close to the track's
        # colour, since some of their texels are the track's too.
        c = cel(pos, n, edge, SLATE_DARK, SLATE, SLATE_DARK, frame.depth(fi) > -0.1)
        return c * tint

    rasterise(canvas, done, back, lambda p, n, e, f: cel(p, n, e, MID, SHADE, SHADE, False) * tint, wrap=True)
    rasterise(canvas, done, frame, paint_frame)
    rasterise(canvas, done, gate, paint_gate)
    rasterise(canvas, done, ring, paint_ring)
    return Image.fromarray(np.clip(bleed(canvas, done), 0, 255).astype(np.uint8))


def paint_chevron_texture(models, size, lens, tint, glow=False):
    """chevron.png and its lit/unlit forms: the moving V and the light."""
    moving, light = models["chevron_moving"], models["chevron_light"]
    canvas = np.zeros((size, size, 3), float)
    done = np.zeros((size, size), bool)
    tint = np.array(tint)

    def paint_moving(pos, n, edge, fi):
        flat = abs(n[2]) > 0.72
        base = (58, 62, 76) if flat else (84, 90, 108)
        c = np.tile(np.array(base, float), (len(pos), 1))
        # Pale ribs across the V, as drawn on the cartoon gate's chevrons.
        rib = (np.sin(pos[:, 1] * 2 * math.pi / 0.11) > 0.55) & flat
        c = mix(c, (150, 160, 178), rib.astype(float) * 0.85)
        c = mix(c, INK, (edge < INK_WIDTH * 0.7).astype(float))
        return c * tint

    def paint_light(pos, n, edge, fi):
        x, y = pos[:, 0], pos[:, 1]
        c = np.tile(np.array(lens, float), (len(pos), 1))
        if glow:
            cy = 4.92
            hot = np.clip(1.0 - np.hypot(x * 2.2, (y - cy) * 1.6) / 0.42, 0, 1)
            c = mix(c, LIME_HOT, hot)
        c = mix(c, INK, (edge < INK_WIDTH * 0.6).astype(float))
        return c if glow else c * tint

    rasterise(canvas, done, moving, paint_moving)
    rasterise(canvas, done, light, paint_light)
    img = np.clip(bleed(canvas, done), 0, 255).astype(np.uint8)
    return Image.fromarray(img).convert("RGBA")




def paint_iris_texture(model, size):
    """The iris blades: pale, ink-edged, so a closed iris shows the cartoon's spiral."""
    canvas = np.zeros((size, size, 3), float)
    done = np.zeros((size, size), bool)

    def paint(pos, n, edge, fi):
        r = np.hypot(pos[:, 0], pos[:, 1])
        c = mix(LIGHT, PALE, np.clip(r / 4.7, 0, 1))
        # faint curved strokes along each blade, the spiral's lines
        stroke = np.abs(np.sin((np.arctan2(pos[:, 1], pos[:, 0]) * 3.0 + r * 1.1) * math.pi)) < 0.06
        c = mix(c, MID, stroke.astype(float) * 0.6)
        return mix(c, INK, (edge < 0.045).astype(float))

    rasterise(canvas, done, model, paint)
    return Image.fromarray(np.clip(bleed(canvas, done), 0, 255).astype(np.uint8))


def spiral_texture(size=512, arms=14):
    """The whirlpool drawn over an open wormhole: ink arms curling out from the centre, the rest clear."""
    k = 4  # drawn large, then shrunk, for smooth lines
    big = size * k
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = big / 2
    rim = big * 0.49
    ink = INK + (225,)
    for arm in range(arms):
        a0 = arm * 2 * math.pi / arms
        pts = []
        for i in range(0, 101):
            t = i / 100
            a = a0 + 2.1 * t ** 0.8  # each arm turns about 120 degrees on its way out
            pts.append((c + rim * t * math.cos(a), c + rim * t * math.sin(a)))
        d.line(pts, fill=ink, width=int(2.2 * k), joint="curve")
    d.ellipse([c - 3 * k, c - 3 * k, c + 3 * k, c + 3 * k], fill=ink)
    return img.resize((size, size), Image.LANCZOS)


# ---------------------------------------------------------------- Infinity DHD

DHD_INK_WIDTH = 0.012  # blocks; the DHD is small, so its lines are finer


def dhd_models(z):
    """JSG's Milky Way DHD parts that are drawn with the DHD's own texture."""
    dhd = MODELS + "milkyway/dhd/"
    models = {}
    for name in ("dhd_base", "button_console", "crystal_holder", "upgrade_cover"):
        models[name] = Model(z.read(dhd + name + ".obj").decode("utf-8", "replace"))
    for name in z.namelist():  # each key's base, and the big button's
        if name.startswith(dhd + "buttons/") and name.endswith("_base.obj"):
            models["key_" + os.path.basename(name)[:-9]] = Model(z.read(name).decode("utf-8", "replace"))
    poo = "assets/jsg/models/point_of_origins/stargate/milkyway/default/dhd.obj"
    if poo in z.namelist():  # the point of origin's key
        models["key_origin"] = Model(z.read(poo).decode("utf-8", "replace"))
    return models


def paint_dhd_texture(models, size):
    """The pedestal pale with ink outlines, a pale tray round a slate console, slate key bases."""
    base = models["dhd_base"]
    top = max(base.v[:, 1])
    canvas = np.zeros((size, size, 3), float)
    done = np.zeros((size, size), bool)

    def inked(c, edge, width=DHD_INK_WIDTH):
        return mix(c, INK, (edge < width).astype(float))

    def paint_body(pos, n, edge, fi):
        x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
        if abs(n[1]) > 0.55 and np.mean(y) > top - 0.75:
            # the top: a slate ring the keys sit in, inside a pale tray
            d = np.hypot(x, z - 0.04)
            c = np.tile(np.array(SLATE, float), (len(pos), 1))
            c = mix(c, PALE, (d > 0.66).astype(float))
            c = mix(c, INK, (np.abs(d - 0.66) < DHD_INK_WIDTH).astype(float))
            return inked(c, edge)
        # the pedestal: pale, lighter where it faces up, with a slate band under the top
        c = mix(MID, PALE, np.full(len(pos), 0.4 + 0.6 * abs(n[1])))
        c = mix(c, SLATE, (np.abs(y - (top - 0.62)) < 0.04).astype(float))
        return inked(c, edge)

    def flat(colour, width=DHD_INK_WIDTH * 0.8):
        def paint(pos, n, edge, fi):
            return inked(np.tile(np.array(colour, float), (len(pos), 1)), edge, width)
        return paint

    # Later parts win where parts share texels, so the ones you see most go last.
    rasterise(canvas, done, models["crystal_holder"], flat(MID))
    rasterise(canvas, done, models["upgrade_cover"], flat(MID))
    rasterise(canvas, done, base, paint_body)
    rasterise(canvas, done, models["button_console"], flat(SLATE))
    for name, model in models.items():
        if name.startswith("key_"):
            rasterise(canvas, done, model, flat(SLATE_DARK))
    return Image.fromarray(np.clip(bleed(canvas, done, 16), 0, 255).astype(np.uint8))


def paint_key_light(level, size=256):
    """The glowing part of a symbol key; JSG has six brightness levels, 0 off to 5 fully lit."""
    t = level / 5.0
    body = mix(np.array([SLATE_DARK]), np.array([LIME]), np.array([t]))[0]
    rim = mix(np.array([MID]), np.array([LIME_HOT]), np.array([t]))[0]
    img = Image.new("RGB", (size, size), tuple(int(v) for v in body))
    d = ImageDraw.Draw(img)
    for i in range(3):
        k = size * (0.05 + i * 0.06)
        d.rectangle([k, k, size - k, size - k], outline=tuple(int(v) for v in rim), width=max(2, size // 64))
    return img


def paint_dome(level, size=256):
    """The big button in the middle: a slate dome that lights lime, brightest at its centre."""
    t = level / 5.0
    yy, xx = np.mgrid[0:size, 0:size] / (size - 1)
    r = np.hypot(xx - 0.5, yy - 0.5) * 2
    base = mix(np.array(SLATE_DARK, float), np.array(LIME, float), np.full(r.shape, t))
    hot = mix(base, np.array(LIME_HOT, float), np.clip(1 - r, 0, 1) * t)
    shine = np.clip(1 - np.hypot(xx - 0.36, yy - 0.32) / 0.16, 0, 1) * (0.35 + 0.4 * t)
    img = mix(hot, np.array(LIGHT, float), shine)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))


def dhd_icon():
    """The DHD's item, 16x16: the pedestal from the front, its top and the dome."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(4, 7), (11, 7), (10, 15), (5, 15)], fill=PALE, outline=INK)
    d.line([(5, 9), (10, 9)], fill=SLATE)
    d.ellipse([0, 2, 15, 9], fill=PALE, outline=INK)
    d.ellipse([3, 3, 12, 8], fill=SLATE, outline=INK)
    d.ellipse([6, 4, 9, 6], fill=LIME, outline=INK)
    return img


# ---------------------------------------------------------------- orange DHD

# In the style of the DHD from Carter's Addon Pack: an orange pedestal with amber panels and
# yellow bands, a dark console with gold-edged keys that light orange, a turquoise dome.
ORANGE = (232, 112, 28)
ORANGE_DEEP = (196, 84, 20)
AMBER = (250, 176, 52)
YELLOW = (255, 214, 92)
CONSOLE = (52, 32, 26)
CONSOLE_LINE = (214, 150, 60)
TURQUOISE = (64, 214, 214)


def paint_orange_dhd_texture(models, size):
    base = models["dhd_base"]
    top = max(base.v[:, 1])
    canvas = np.zeros((size, size, 3), float)
    done = np.zeros((size, size), bool)

    def paint_body(pos, n, edge, fi):
        x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
        if abs(n[1]) > 0.55 and np.mean(y) > top - 0.75:
            # the top: the console's dark ring with gold edges, inside an orange bezel
            d = np.hypot(x, z - 0.04)
            c = np.tile(np.array(CONSOLE, float), (len(pos), 1))
            c = mix(c, ORANGE, (d > 0.66).astype(float))
            c = mix(c, YELLOW, (np.abs(d - 0.70) < 0.018).astype(float))
            return mix(c, CONSOLE_LINE, ((edge < 0.012) & (d <= 0.66)).astype(float))
        # the pedestal: orange, with wide amber panels and yellow bands
        c = np.tile(np.array(ORANGE, float), (len(pos), 1))
        c = mix(c, AMBER, (np.sin(np.arctan2(z, x) * 5) > 0.45).astype(float) * 0.85)
        band = (np.abs(y - (top - 0.62)) < 0.035) | (np.abs(y - 0.12) < 0.03)
        c = mix(c, YELLOW, band.astype(float))
        return mix(c, ORANGE_DEEP, (edge < 0.012).astype(float) * 0.9)

    def flat(colour, line, width):
        def paint(pos, n, edge, fi):
            return mix(np.tile(np.array(colour, float), (len(pos), 1)), line, (edge < width).astype(float))
        return paint

    rasterise(canvas, done, models["crystal_holder"], flat(ORANGE_DEEP, CONSOLE, 0.010))
    rasterise(canvas, done, models["upgrade_cover"], flat(ORANGE_DEEP, CONSOLE, 0.010))
    rasterise(canvas, done, base, paint_body)
    rasterise(canvas, done, models["button_console"], flat(CONSOLE, CONSOLE_LINE, 0.010))
    for name, model in models.items():
        if name.startswith("key_"):
            rasterise(canvas, done, model, flat((70, 44, 32), CONSOLE_LINE, 0.008))
    return Image.fromarray(np.clip(bleed(canvas, done, 16), 0, 255).astype(np.uint8))


def paint_orange_key_light(level, size=256):
    """A key's light: dark bronze when off, glowing orange when lit."""
    t = level / 5.0
    body = mix(np.array([(86, 58, 40)]), np.array([(255, 168, 56)]), np.array([t]))[0]
    rim = mix(np.array([(150, 100, 48)]), np.array([(255, 226, 140)]), np.array([t]))[0]
    img = Image.new("RGB", (size, size), tuple(int(v) for v in body))
    d = ImageDraw.Draw(img)
    for i in range(3):
        k = size * (0.04 + i * 0.05)
        d.rectangle([k, k, size - k, size - k], outline=tuple(int(v) for v in rim), width=max(2, size // 64))
    return img


def paint_orange_dome(level, size=256):
    """The big button: a turquoise glass dome that brightens as it lights."""
    t = level / 5.0
    yy, xx = np.mgrid[0:size, 0:size] / (size - 1)
    r = np.hypot(xx - 0.5, yy - 0.5) * 2
    base = mix(np.array((20, 92, 104), float), np.array(TURQUOISE, float), np.full(r.shape, 0.35 + 0.65 * t))
    hot = mix(base, np.array((150, 255, 250), float), np.clip(1 - r, 0, 1) * t)
    shine = np.clip(1 - np.hypot(xx - 0.36, yy - 0.32) / 0.16, 0, 1) * (0.5 + 0.5 * t)
    img = mix(hot, np.array((255, 255, 255), float), shine)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))


def orange_dhd_icon():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(4, 7), (11, 7), (10, 15), (5, 15)], fill=ORANGE, outline=ORANGE_DEEP)
    d.line([(7, 8), (7, 14)], fill=AMBER)
    d.line([(5, 10), (10, 10)], fill=YELLOW)
    d.ellipse([0, 2, 15, 9], fill=ORANGE, outline=YELLOW)
    d.ellipse([3, 3, 12, 8], fill=CONSOLE, outline=CONSOLE_LINE)
    d.ellipse([6, 4, 9, 6], fill=TURQUOISE)
    return img


# ---------------------------------------------------------------- blocks

def block_textures():
    """The 16x16 blocks you place to build the gate, before it forms."""
    def canvas(fill):
        img = Image.new("RGB", (16, 16), fill)
        return img, ImageDraw.Draw(img)

    def frame(d):
        d.rectangle([0, 0, 15, 15], outline=INK)

    sides, d = canvas(MID)
    frame(d)
    d.line([(1, 1), (14, 1)], fill=PALE)
    d.line([(1, 14), (14, 14)], fill=SHADE)

    ring, d = canvas(PALE)
    frame(d)
    d.rectangle([2, 4, 13, 11], fill=SLATE, outline=INK)
    d.line([(5, 6), (7, 9), (10, 6)], fill=GLYPH)  # a symbol on its panel
    d.point([(8, 6)], fill=GLYPH)

    chevron, d = canvas(PALE)
    frame(d)
    d.polygon([(3, 3), (12, 3), (7, 12)], fill=SLATE_DARK, outline=INK)
    d.polygon([(5, 4), (10, 4), (7, 9)], fill=LIME)

    base, d = canvas(PALE)
    frame(d)
    d.ellipse([2, 2, 13, 13], fill=SLATE, outline=INK)
    d.ellipse([5, 5, 10, 10], fill=LIGHT, outline=INK)
    d.point([(7, 2), (2, 7), (13, 7), (7, 13)], fill=LIME)
    return {"infinity_stargate_sides": sides, "infinity_stargate_ring_front": ring,
            "infinity_stargate_chevron_front": chevron, "infinity_stargate_base_front": base}


# ---------------------------------------------------------------- data

def write_json(data, *path):
    p = os.path.join(RESOURCES, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def write_data():
    lang = {"itemGroup.jsginfinity": "Infinity Stargate"}
    for block, (front, name, jsg_block) in BLOCKS.items():
        # The same block states as JSG's Milky Way blocks: facing, facing_vertical, render_block.
        variants = {}
        for facing, y in (("south", 180), ("west", 270), ("north", 0), ("east", 90)):
            for vertical, x in ((0, 0), (2, 90), (1, 270)):
                for render in ("false", "true"):
                    variants["facing=%s,facing_vertical=%d,render_block=%s" % (facing, vertical, render)] = {
                        "y": y, "x": x, "model": "%s:block/%s" % (MOD, block)}
        write_json({"variants": variants}, "assets", MOD, "blockstates", block + ".json")
        sides = "%s:block/infinity_stargate_sides" % MOD
        write_json({"parent": "minecraft:block/cube", "textures": {
            "particle": sides, "north": "%s:block/%s" % (MOD, front),
            "south": sides, "west": sides, "east": sides, "up": sides, "down": sides}},
            "assets", MOD, "models", "block", block + ".json")
        write_json({"parent": "%s:block/%s" % (MOD, block)}, "assets", MOD, "models", "item", block + ".json")

        part = name.split()[-1].lower()
        lang["block.%s.%s" % (MOD, block)] = name
        if part == "base":
            lang["block.%s.%s.tooltip" % (MOD, block)] = "The main block of the Infinity gate"
            lang["block.%s.%s.tooltip.extended" % (MOD, block)] = (
                "Place this block first when building a stargate.%nl%When placed, it will show you a diagram%nl%"
                "of how the stargate should be built.")
        else:
            lang["block.%s.%s.tooltip" % (MOD, block)] = (
                "The construction block of the Infinity gate" if part == "ring" else "The locking mechanism of the Infinity gate")
            lang["block.%s.%s.tooltip.extended" % (MOD, block)] = "You need this block to complete building a new stargate."

        # A JSG Milky Way block and lime dye make the Infinity one.
        write_json({"type": "minecraft:crafting_shapeless", "group": "jsginfinity", "category": "building",
                    "ingredients": [{"item": "jsg:" + jsg_block}, {"item": "minecraft:lime_dye"}],
                    "result": {"item": "%s:%s" % (MOD, block)}},
                   "data", MOD, "recipes", block + ".json")

        entry = {"type": "minecraft:item", "name": "%s:%s" % (MOD, block)}
        if part == "base":  # keeps the gate's upgrades, settings and energy, as JSG's base block does
            entry["functions"] = [{"function": "minecraft:copy_nbt", "source": "block_entity", "ops": [
                {"op": "replace", "source": key, "target": key}
                for key in ("itemHandler", "config", "stargateEnergyManager")]}]
        write_json({"type": "minecraft:block", "pools": [{
            "rolls": 1.0, "bonus_rolls": 0.0,
            "conditions": [{"condition": "minecraft:survives_explosion"}],
            "entries": [entry]}]}, "data", MOD, "loot_tables", "blocks", block + ".json")
    # The DHDs: JSG's own Milky Way DHD underneath, each drawn by the add-on's renderer in its look.
    for dhd, (dhd_name, dye) in DHDS.items():
        write_json({"variants": {"": {"model": "jsg:block/dhd_generic"}}}, "assets", MOD, "blockstates", dhd + ".json")
        write_json({"parent": "minecraft:item/generated", "textures": {"layer0": "%s:item/%s" % (MOD, dhd)}},
                   "assets", MOD, "models", "item", dhd + ".json")
        key = "block.%s.%s" % (MOD, dhd)
        lang.update({
            key: dhd_name,
            key + ".tooltip": "Dials Milky Way gates, the Infinity gate among them",
            key + ".no_crystal_warn": "The DHD has no control crystal",
            key + ".not_linked_warn": "The DHD isn't linked to a gate",
            key + ".not_enough_power": "Not enough power",
            key + ".incoming_wormhole_warn": "An incoming wormhole can't be closed from here",
            key + ".computer_dial": "A computer is dialling",
        })
        write_json({"type": "minecraft:crafting_shapeless", "group": "jsginfinity", "category": "redstone",
                    "ingredients": [{"item": "jsg:dhd_milkyway"}, {"item": "minecraft:" + dye}],
                    "result": {"item": "%s:%s" % (MOD, dhd)}}, "data", MOD, "recipes", dhd + ".json")
        write_json({"type": "minecraft:block", "pools": [{
            "rolls": 1.0, "bonus_rolls": 0.0,
            "conditions": [{"condition": "minecraft:survives_explosion"}],
            "entries": [{"type": "minecraft:item", "name": "%s:%s" % (MOD, dhd)}]}]},
            "data", MOD, "loot_tables", "blocks", dhd + ".json")

    # JSG finds gates, their parts and DHDs by block tags, and links a gate to a DHD only when
    # each is in the other's tag. The Infinity blocks join the tags their Milky Way twins are in.
    tags = {
        "stargate/classic_stargate_bases": ["infinity_stargate_base_block"],
        "stargate/classic_stargate_parts": ["infinity_stargate_ring_block", "infinity_stargate_chevron_block"],
        "stargate/stargate_milkyway_linkable": list(DHDS),  # what a Milky Way gate links to
        "dhd/dhd_milkyway_linkable": ["infinity_stargate_base_block"],  # what a Milky Way DHD links to
        "dhd/dhd_any": list(DHDS),
    }
    for tag, blocks in tags.items():
        write_json({"replace": False, "values": ["%s:%s" % (MOD, b) for b in blocks]},
                   "data", "jsg", "tags", "blocks", tag + ".json")

    write_json(lang, "assets", MOD, "lang", "en_us.json")
    print("wrote block states, models, names, recipes, loot tables and tags")


def save(img, *path):
    p = os.path.join(OUT, *path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    img.save(p, "PNG", optimize=True)
    print("wrote", os.path.relpath(p, RESOURCES))


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    z = zipfile.ZipFile(sys.argv[1])
    mw = {n: Model(z.read(MODELS + "milkyway/%s.obj" % n).decode("utf-8", "replace")) for n in
          ("gate", "ring", "chevron_frame", "chevron_back", "chevron_moving", "chevron_light")}
    plain = (1, 1, 1)
    save(paint_gate_texture(mw, 2048, plain), "gate", "infinity_gate.png")
    save(paint_chevron_texture(mw, 256, (70, 80, 46), plain), "gate", "chevron.png")
    save(paint_chevron_texture(mw, 256, LIME, plain, glow=True), "gate", "chevron_light.png")
    save(paint_chevron_texture(mw, 256, (58, 64, 44), plain), "gate", "chevron_light_off.png")
    save(paint_iris_texture(Model(z.read(MODELS + "iris/iris_blade.obj").decode("utf-8", "replace")), 1024),
         "gate", "iris_blade.png")
    save(spiral_texture(), "gate", "wormhole_spiral.png")
    for name, img in block_textures().items():
        save(img, "block", name + ".png")
    dhd = dhd_models(z)
    looks = {  # folder: (body, key light, dome, item icon)
        "infinity": (paint_dhd_texture, paint_key_light, paint_dome, dhd_icon),
        "orange": (paint_orange_dhd_texture, paint_orange_key_light, paint_orange_dome, orange_dhd_icon),
    }
    for look, (body, key, dome, icon) in looks.items():
        save(body(dhd, 2048), "dhd", look, "dhd_base.png")
        for level in range(6):
            save(key(level), "dhd", look, "dhd_button_light_%d.png" % level)
            save(dome(level), "dhd", look, "dhd_brb_%d.png" % level)
        save(icon(), "item", look + "_dhd.png")
    write_data()


if __name__ == "__main__":
    main()
