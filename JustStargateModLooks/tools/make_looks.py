#!/usr/bin/env python3
"""Build the Just Stargate Mod look packs.

    python3 tools/make_looks.py <jsg-1.20.1 jar> <output folder>

Every texture is painted here from scratch. The script reads only the shapes
and UV layouts of JSG's models from the jar you give it, so the new textures
line up with JSG's gate, iris and DHD. No pixel of JSG's own textures is read
or copied.

Each texel of a texture is traced back to the point of the model it lands on.
That point's position, the direction its face looks and the sharp edges near
it decide the colour: flat cartoon shading with ink outlines for the Infinity
gate, orange panels and yellow trim for the orange DHD.
"""

import io
import json
import math
import os
import sys
import zipfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

MODELS = "assets/jsg/models/tesr/"
TEXTURES = "assets/jsg/textures/tesr/"
PACK_FORMAT = 15  # Minecraft 1.20.1

# JSG gives Milky Way gates a different texture set in some biomes. The packs
# fill every set, with a light tint, so the look holds everywhere.
BIOME_SUFFIXES = {
    "": (1.00, 1.00, 1.00),
    "_aged": (1.04, 0.98, 0.88),
    "_frost": (0.97, 1.01, 1.08),
    "_mossy": (0.93, 1.03, 0.90),
    "_sooty": (0.80, 0.80, 0.82),
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


def grain(pos, scale, amount, seed=0):
    """Soft, stable noise from a 3D point, for a little paper-like grain."""
    x, y, z = pos[:, 0] * scale, pos[:, 1] * scale, pos[:, 2] * scale
    v = (np.sin(x * 1.7 + y * 3.1 + seed) * np.sin(y * 2.3 - z * 1.3 + seed * 2)
         + 0.5 * np.sin(x * 5.3 - y * 4.1 + z * 2.9 + seed * 3))
    return (v / 1.5) * amount


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
        c = c + grain(pos, 9.0, 4.0)[:, None]
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
        return (c + grain(pos, 11.0, 3.0)[:, None]) * tint

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


def paint_iris_texture(model, size, tint):
    """The iris blades: pale, ink-edged, so a closed iris shows the cartoon's spiral."""
    canvas = np.zeros((size, size, 3), float)
    done = np.zeros((size, size), bool)
    tint = np.array(tint)

    def paint(pos, n, edge, fi):
        r = np.hypot(pos[:, 0], pos[:, 1])
        c = mix(LIGHT, PALE, np.clip(r / 4.7, 0, 1))
        # Faint curved strokes along each blade, the spiral's lines.
        stroke = np.abs(np.sin((np.arctan2(pos[:, 1], pos[:, 0]) * 3.0 + r * 1.1) * math.pi)) < 0.06
        c = mix(c, MID, stroke.astype(float) * 0.6)
        c = mix(c, INK, (edge < 0.045).astype(float))
        return (c + grain(pos, 7.0, 3.0)[:, None]) * tint

    rasterise(canvas, done, model, paint)
    return Image.fromarray(np.clip(bleed(canvas, done), 0, 255).astype(np.uint8))


# ---------------------------------------------------------------- orange DHD

ORANGE = (232, 112, 28)
ORANGE_DEEP = (196, 84, 20)
AMBER = (250, 176, 52)
YELLOW = (255, 214, 92)
CONSOLE = (52, 32, 26)
CONSOLE_LINE = (214, 150, 60)
TURQUOISE = (64, 214, 214)


def paint_dhd_texture(models, size):
    base, console = models["dhd_base"], models["button_console"]
    extra = [models[k] for k in models if k.endswith("_base") and k[0].isdigit()]
    canvas = np.zeros((size, size, 3), float)
    done = np.zeros((size, size), bool)
    top = max(base.v[:, 1])

    def paint_body(pos, n, edge, fi):
        x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
        a = np.arctan2(z, x)
        if abs(n[1]) > 0.55 and np.mean(y) > top - 0.75:
            # The top. The console's ring is dark, with gold edges; round it,
            # an orange bezel with a yellow line, as on the orange DHD.
            d = np.hypot(x, z - 0.04)
            c = np.tile(np.array(CONSOLE, float), (len(pos), 1))
            c = mix(c, ORANGE, (d > 0.66).astype(float))
            c = mix(c, YELLOW, (np.abs(d - 0.70) < 0.018).astype(float))
            c = mix(c, CONSOLE_LINE, ((edge < 0.012) & (d <= 0.66)).astype(float))
            return c
        # The pedestal: orange, with wide amber panels and yellow bands.
        c = np.tile(np.array(ORANGE, float), (len(pos), 1))
        panel = np.sin(a * 5) > 0.45
        c = mix(c, AMBER, panel.astype(float) * 0.85)
        band = (np.abs(y - (top - 0.62)) < 0.035) | (np.abs(y - 0.12) < 0.03)
        c = mix(c, YELLOW, band.astype(float))
        c = mix(c, ORANGE_DEEP, (edge < 0.012).astype(float) * 0.9)
        return c + grain(pos, 30.0, 4.0)[:, None]

    def paint_console(pos, n, edge, fi):
        c = np.tile(np.array(CONSOLE, float), (len(pos), 1))
        return mix(c, CONSOLE_LINE, (edge < 0.010).astype(float))

    def paint_button_base(pos, n, edge, fi):
        c = np.tile(np.array((70, 44, 32), float), (len(pos), 1))
        return mix(c, CONSOLE_LINE, (edge < 0.008).astype(float) * 0.8)

    rasterise(canvas, done, base, paint_body)
    rasterise(canvas, done, console, paint_console)
    for m in extra:
        rasterise(canvas, done, m, paint_button_base)
    return Image.fromarray(np.clip(bleed(canvas, done, 16), 0, 255).astype(np.uint8))


def paint_button_light(level, size=512):
    """The 38 symbol keys share one texture; level 0 is off, 5 fully lit."""
    t = level / 5.0
    body = mix(np.array([[86, 58, 40]]), np.array([[255, 168, 56]]), np.array([t]))[0]
    rim = mix(np.array([[150, 100, 48]]), np.array([[255, 226, 140]]), np.array([t]))[0]
    img = Image.new("RGB", (size, size), tuple(int(v) for v in body))
    d = ImageDraw.Draw(img)
    for i in range(3):
        k = size * (0.04 + i * 0.05)
        d.rectangle([k, k, size - k, size - k], outline=tuple(int(v) for v in rim), width=max(2, size // 64))
    if level:
        img = Image.blend(img, img.filter(ImageFilter.GaussianBlur(size / 24)), 0.4)
    return img


def paint_dome(level, size=256):
    """The big button in the middle: a turquoise dome that brightens as it lights."""
    t = level / 5.0
    yy, xx = np.mgrid[0:size, 0:size] / (size - 1)
    r = np.hypot(xx - 0.5, yy - 0.5) * 2
    dark = np.array([20, 92, 104], float)
    lit = np.array([150, 255, 250], float)
    base = mix(dark, TURQUOISE, np.full(r.shape, 0.35 + 0.65 * t))
    hot = mix(base, lit, np.clip(1 - r, 0, 1) * t)
    # A soft highlight up and to the left, as on glass.
    spec = np.clip(1 - np.hypot(xx - 0.36, yy - 0.32) / 0.16, 0, 1) * (0.5 + 0.5 * t)
    img = mix(hot, (255, 255, 255), spec)
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))


# ---------------------------------------------------------------- packs

def jpg(img, quality=90):
    b = io.BytesIO()
    img.convert("RGB").save(b, "JPEG", quality=quality, optimize=True)
    return b.getvalue()


def png(img):
    b = io.BytesIO()
    img.save(b, "PNG", optimize=True)
    return b.getvalue()


def write_pack(zip_path, description, files, icon):
    meta = {"pack": {"pack_format": PACK_FORMAT, "description": description}}
    files = dict(files)
    files["pack.mcmeta"] = (json.dumps(meta, indent=2) + "\n").encode()
    files["pack.png"] = png(icon)
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for rel in sorted(files):
            info = zipfile.ZipInfo(rel, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, files[rel])


def icon_gate():
    s = 128
    img = Image.new("RGB", (s, s), (246, 238, 196))
    d = ImageDraw.Draw(img)
    for i in range(10):  # the yellow-green spikes of the cartoon gate room
        y = 8 + i * 12
        d.polygon([(0, y), (22, y + 4), (0, y + 8)], fill=LIME)
        d.polygon([(s, y), (s - 22, y + 4), (s, y + 8)], fill=LIME)
    d.ellipse([18, 14, 110, 106], fill=PALE, outline=INK, width=4)
    d.ellipse([30, 26, 98, 94], fill=SLATE, outline=INK, width=3)
    d.ellipse([38, 34, 90, 86], fill=LIGHT, outline=INK, width=3)
    cx, cy = 64, 60
    for k in range(10):  # the pale whirlpool
        a0 = k * 2 * math.pi / 10
        pts = [(cx + r * math.cos(a0 + r / 9), cy + r * math.sin(a0 + r / 9)) for r in range(0, 26, 2)]
        d.line(pts, fill=INK, width=1)
    for k in range(9):
        a = -math.pi / 2 + k * 2 * math.pi / 9
        x, y = cx + 47 * math.cos(a), cy + 47 * math.sin(a)
        d.polygon([(x - 5 * math.sin(a) * -1, y), (x + 4 * math.cos(a), y + 4 * math.sin(a)), (x, y + 5)], fill=LIME)
    return img


def icon_dhd():
    s = 128
    img = Image.new("RGB", (s, s), (40, 28, 24))
    d = ImageDraw.Draw(img)
    d.polygon([(30, 70), (98, 70), (88, 124), (40, 124)], fill=ORANGE, outline=ORANGE_DEEP)
    d.rectangle([58, 72, 70, 124], fill=AMBER)
    d.ellipse([10, 22, 118, 82], fill=ORANGE, outline=YELLOW, width=3)
    d.ellipse([22, 30, 106, 74], fill=CONSOLE, outline=CONSOLE_LINE, width=2)
    for k in range(19):
        a = k * 2 * math.pi / 19
        d.line([(64 + 26 * math.cos(a), 52 + 13 * math.sin(a)), (64 + 40 * math.cos(a), 52 + 20 * math.sin(a))],
               fill=CONSOLE_LINE, width=1)
    d.ellipse([50, 44, 78, 60], fill=TURQUOISE, outline=(20, 92, 104), width=2)
    return img


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    jar, out = sys.argv[1], sys.argv[2]
    z = zipfile.ZipFile(jar)

    def model(path):
        return Model(z.read(MODELS + path).decode("utf-8", "replace"))

    mw = {n: model("milkyway/%s.obj" % n) for n in
          ("gate", "ring", "chevron_frame", "chevron_back", "chevron_moving", "chevron_light")}
    iris = model("iris/iris_blade.obj")
    dhd = {"dhd_base": model("milkyway/dhd/dhd_base.obj"),
           "button_console": model("milkyway/dhd/button_console.obj")}
    for name in z.namelist():
        if name.startswith(MODELS + "milkyway/dhd/buttons/") and name.endswith("_base.obj"):
            key = os.path.basename(name)[:-4]
            if key[0].isdigit():
                dhd[key] = Model(z.read(name).decode("utf-8", "replace"))

    gate_files = {}
    for suffix, tint in BIOME_SUFFIXES.items():
        print("Infinity gate%s..." % (suffix or ""))
        gate_files[TEXTURES + "milkyway/gatering%s.jpg" % suffix] = jpg(paint_gate_texture(mw, 2048, tint))
        unlit = paint_chevron_texture(mw, 256, (70, 80, 46), tint)
        lit = paint_chevron_texture(mw, 256, LIME, tint, glow=True)
        off = paint_chevron_texture(mw, 256, (58, 64, 44), tint)
        gate_files[TEXTURES + "milkyway/chevron%s.png" % suffix] = png(unlit)
        gate_files[TEXTURES + "milkyway/chevron_light%s.png" % suffix] = png(lit)
        gate_files[TEXTURES + "milkyway/chevron_light_off%s.png" % suffix] = png(off)
    print("Infinity iris...")
    gate_files[TEXTURES + "iris/iris_blade.jpg"] = jpg(paint_iris_texture(iris, 1024, (1, 1, 1)))

    print("Orange DHD...")
    dhd_files = {TEXTURES + "milkyway/dhd/dhd_base.jpg": jpg(paint_dhd_texture(dhd, 2048), 88)}
    for level in range(6):
        dhd_files[TEXTURES + "milkyway/dhd/dhd_button_light_%d.jpg" % level] = jpg(paint_button_light(level))
        dhd_files[TEXTURES + "milkyway/dhd/dhd_brb_%d.jpg" % level] = jpg(paint_dome(level))

    os.makedirs(out, exist_ok=True)
    write_pack(os.path.join(out, "JSG-Infinity-Gate-1.20.1.zip"),
               "Just Stargate Mod: the Milky Way gate as drawn in Stargate Infinity", gate_files, icon_gate())
    write_pack(os.path.join(out, "JSG-Orange-DHD-1.20.1.zip"),
               "Just Stargate Mod: an orange DHD with a turquoise dome", dhd_files, icon_dhd())
    print("Done:", out)


if __name__ == "__main__":
    main()
