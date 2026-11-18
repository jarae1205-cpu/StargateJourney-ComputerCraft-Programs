"""
Builds the Stargate Infinity resource pack for Just Stargate Mod (JSG) 1.20.1.

Every texture in the pack is drawn here. Nothing is copied or recoloured from
JSG: the script only reads JSG's gate models (the .obj files in the JSG jar) to
learn where each part of the gate sits on its texture, then paints that part
in the cartoon style of the animated series: flat pale tones, ink lines along
the edges, black glyphs, dark chevrons that light lime-yellow, and a pale
whirlpool with ink lines for the wormhole.

    python3 make_pack.py <jsg-1.20.1-x.jar> <output dir> [zip file] [--full] [--small]

--full makes the wormhole sheets as large as JSG's own; --small makes a quick low-resolution
pack for checking with preview.py.

Needs Pillow and numpy.
"""
import io
import json
import math
import os
import sys
import zipfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

Image.MAX_IMAGE_PIXELS = None

TESR = "assets/jsg/textures/tesr/"
MODELS = "assets/jsg/models/tesr/"

# --------------------------------------------------------------------------
# colours: the same palette as the Infinity look of the Stargate Journey pack
# --------------------------------------------------------------------------


def rgb(h):
    return np.array([(h >> 16) & 255, (h >> 8) & 255, h & 255], dtype=np.float32)


INK = rgb(0x14161C)
GLYPH_SIDE = rgb(0x2E3440)
# JSG lights its gate dimly (in a test it drew the ring at about 40% of the texture's brightness),
# so the ring's tones sit close to white to come out as the show's pale grey
PALE = rgb(0xF6F8FC)       # lit front of the outer ring
STONE = rgb(0xE8EDF5)      # front faces
MID = rgb(0xC7D0DE)        # sides
SHADOW = rgb(0xAAB5C7)     # backs and undersides
TRACK = rgb(0xD6DDE8)      # the symbol track
CHEVRON = rgb(0x3A4252)    # chevron body
CHEVRON_DARK = rgb(0x262B36)
LIME = [rgb(0x6E8A10), rgb(0xB8D82C), rgb(0xD6F23C), rgb(0xF7FFB0)]
LIME_OFF = [rgb(0x1C2028), rgb(0x2E3440), rgb(0x3C4454)]
IRIS = rgb(0xEEF3F9)
IRIS_SIDE = rgb(0xC2CDDC)

# JSG swaps in these textures in some biomes; the cartoon gate gets a light tint instead of weathering
BIOME_TINTS = {
    "": None,
    "_aged": (rgb(0xC8B48C), 0.22),
    "_frost": (rgb(0xF4FAFF), 0.38),
    "_mossy": (rgb(0x7FA45A), 0.22),
    "_sooty": (rgb(0x20242C), 0.18),
}


def ramp(colors, t):
    """Colour along a list of colours for t in 0..1 (t is an array)."""
    t = np.clip(t, 0.0, 1.0)[..., None]
    pos = t * (len(colors) - 1)
    i = np.minimum(pos.astype(int), len(colors) - 2)
    f = pos - i
    stack = np.stack(colors)
    a = stack[i[..., 0]]
    b = stack[i[..., 0] + 1]
    return a + (b - a) * f


# --------------------------------------------------------------------------
# models
# --------------------------------------------------------------------------


class Model:
    def __init__(self, text):
        v, vt, faces = [], [], []
        for line in text.splitlines():
            p = line.split()
            if not p:
                continue
            if p[0] == "v":
                v.append([float(x) for x in p[1:4]])
            elif p[0] == "vt":
                vt.append([float(x) for x in p[1:3]])
            elif p[0] == "f":
                face = []
                for c in p[1:]:
                    parts = c.split("/")
                    face.append((int(parts[0]) - 1, int(parts[1]) - 1 if len(parts) > 1 and parts[1] else -1))
                faces.append(face)
        self.v = np.array(v, dtype=np.float64)
        self.vt = np.array(vt, dtype=np.float64) if vt else np.zeros((1, 2))
        self.faces = [f for f in faces if len(f) >= 3]
        self.normals = np.array([self._normal(f) for f in self.faces])
        self.centers = np.array([self.v[[i for i, _ in f]].mean(axis=0) for f in self.faces])
        self.uv_centers = np.array([self.vt[[t for _, t in f]].mean(axis=0) for f in self.faces])

    def _normal(self, f):
        pts = self.v[[i for i, _ in f]]
        n = np.zeros(3)
        for k in range(len(pts)):  # Newell's method, robust for any polygon
            a, b = pts[k], pts[(k + 1) % len(pts)]
            n += np.array([(a[1] - b[1]) * (a[2] + b[2]), (a[2] - b[2]) * (a[0] + b[0]), (a[0] - b[0]) * (a[1] + b[1])])
        length = np.linalg.norm(n)
        return n / length if length > 0 else np.array([0.0, 0.0, 1.0])

    def feature_edges(self, angle=32):
        """Edges where the surface folds by more than `angle` degrees, or that border nothing:
        that is where a cartoon draws its ink lines. Yields (face index, uv a, uv b)."""
        edges = {}
        key = lambda i: tuple(np.round(self.v[i], 4))
        for fi, f in enumerate(self.faces):
            for k in range(len(f)):
                a, b = f[k], f[(k + 1) % len(f)]
                ka, kb = key(a[0]), key(b[0])
                if ka == kb:
                    continue
                edges.setdefault(tuple(sorted((ka, kb))), []).append((fi, a[1], b[1]))
        cos_limit = math.cos(math.radians(angle))
        for uses in edges.values():
            fold = len(uses) == 1
            if not fold:
                ns = self.normals[[u[0] for u in uses]]
                fold = (ns @ ns.T).min() < cos_limit
            if fold:
                for fi, ta, tb in uses:
                    yield fi, self.vt[ta], self.vt[tb]


def load_model(jar, path):
    return Model(jar.read(MODELS + path).decode("utf-8", "replace"))


# --------------------------------------------------------------------------
# baking: paint each face of a model where it lands on its texture
# --------------------------------------------------------------------------


def bake(model, size, paint, ink_width, ink=INK, face_filter=None, angle=32, wrap=False):
    """Fills every face's patch of the texture with paint(face index, positions, normal),
    then draws ink along the folds. Returns float RGB and a coverage mask."""
    img = np.zeros((size, size, 3), dtype=np.float32)
    cover = np.zeros((size, size), dtype=bool)
    for fi, f in enumerate(model.faces):
        if face_filter and not face_filter(fi):
            continue
        pos3 = model.v[[i for i, _ in f]]
        uv = model.vt[[t for _, t in f]].copy()
        if wrap:
            uv = uv - np.floor(uv.min(axis=0))
        px = np.stack([uv[:, 0] * size - 0.5, (1 - uv[:, 1]) * size - 0.5], axis=1)
        for k in range(1, len(f) - 1):  # fan of triangles
            tri = px[[0, k, k + 1]]
            p3 = pos3[[0, k, k + 1]]
            x0, y0 = np.floor(tri.min(axis=0) - 1).astype(int)
            x1, y1 = np.ceil(tri.max(axis=0) + 1).astype(int)
            x0, y0 = max(x0, 0), max(y0, 0)
            x1, y1 = min(x1, size - 1), min(y1, size - 1)
            if x1 < x0 or y1 < y0:
                continue
            ys, xs = np.mgrid[y0:y1 + 1, x0:x1 + 1]
            (ax, ay), (bx, by), (cx, cy) = tri
            det = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
            if abs(det) < 1e-9:
                continue
            l1 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / det
            l2 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / det
            l3 = 1 - l1 - l2
            # a little over half a pixel of slack so neighbouring faces meet without gaps
            slack = 0.75 / max(1.0, math.sqrt(abs(det)))
            inside = (l1 >= -slack) & (l2 >= -slack) & (l3 >= -slack)
            if not inside.any():
                continue
            pos = (l1[inside, None] * p3[0] + l2[inside, None] * p3[1] + l3[inside, None] * p3[2])
            img[ys[inside], xs[inside]] = paint(fi, pos, model.normals[fi])
            cover[ys[inside], xs[inside]] = True
    if ink_width:
        mask = Image.new("L", (size, size), 0)
        d = ImageDraw.Draw(mask)
        for fi, a, b in model.feature_edges(angle):
            if face_filter and not face_filter(fi):
                continue
            if wrap:
                base = np.floor(np.minimum(a, b))
                a, b = a - base, b - base
            pa = (a[0] * size - 0.5, (1 - a[1]) * size - 0.5)
            pb = (b[0] * size - 0.5, (1 - b[1]) * size - 0.5)
            d.line([pa, pb], fill=255, width=ink_width)
            r = ink_width / 2
            for p in (pa, pb):
                d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=255)
        m = (np.asarray(mask, dtype=np.float32) / 255.0)[..., None]
        m = m * cover[..., None]
        img = img * (1 - m) + ink * m
    return img, cover


def pad(img, cover, steps=12):
    """Spreads colour into the unused parts of the texture so mipmaps don't bleed dark seams."""
    img = img.copy()
    cover = cover.copy()
    for _ in range(steps):
        if cover.all():
            break
        acc = np.zeros_like(img)
        cnt = np.zeros(cover.shape, dtype=np.float32)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            c = np.roll(cover, (dy, dx), axis=(0, 1))
            acc += np.roll(img, (dy, dx), axis=(0, 1)) * c[..., None]
            cnt += c
        grow = (~cover) & (cnt > 0)
        img[grow] = acc[grow] / cnt[grow, None]
        cover = cover | grow
    return img


def to_image(arr):
    return Image.fromarray(np.clip(arr + 0.5, 0, 255).astype(np.uint8), "RGB")


# --------------------------------------------------------------------------
# the gate
# --------------------------------------------------------------------------


def shade_by_normal(n, front, side, back):
    if n[2] > 0.7:
        return front
    if n[2] < -0.7:
        return back
    return side


def gate_ring_texture(jar, size=2048, tint=None):
    """gatering.jpg: the outer ring (gate.obj) and the turning symbol ring (ring.obj) share it."""
    gate = load_model(jar, "milkyway/gate.obj")
    ring = load_model(jar, "milkyway/ring.obj")

    def gate_paint(fi, pos, n):
        r = np.hypot(pos[:, 0], pos[:, 1])
        if n[2] > 0.7:
            # front: the rim is lit, the band just outside the symbol track a step darker
            col = np.where((r > 4.75)[:, None], PALE, STONE)
            return col
        if n[2] < -0.7:
            return SHADOW
        # sides: faces turned outward catch the light, those turned inward are in shadow
        radial = (pos[:, 0] * n[0] + pos[:, 1] * n[1]) / np.maximum(r, 1e-6)
        return np.where((radial > 0)[:, None], MID, SHADOW)

    # the glyphs are raised shapes whose tops share the upper right of the texture
    glyph = (ring.uv_centers[:, 0] > 0.53) & (ring.uv_centers[:, 1] > 0.62)

    def ring_paint(fi, pos, n):
        if glyph[fi]:
            return INK if n[2] > 0.9 else GLYPH_SIDE
        if n[2] > 0.7:
            return np.where((pos[:, 2] > 0.182)[:, None], STONE, TRACK)
        if n[2] < -0.7:
            return SHADOW
        return MID

    w = max(2, size // 512)
    img_g, cov_g = bake(gate, size, gate_paint, w + 1)
    img_r, cov_r = bake(ring, size, ring_paint, w)
    img = np.where(cov_r[..., None], img_r, img_g)
    cover = cov_g | cov_r
    img = pad(img, cover)
    img[~cover] = STONE
    if tint is not None:
        col, amount = tint
        img = img * (1 - amount) + col * amount
    return to_image(img)


def chevron_textures(size=256):
    """chevron.png (body), chevron_light.png (lit) and chevron_light_off.png (dark)."""
    yy, xx = np.mgrid[0:size, 0:size] / size
    body = np.zeros((size, size, 4), dtype=np.float32)
    # left half: the chevron's body, dark slate with a darker lower part
    t = np.clip((yy - 0.15) / 0.85, 0, 1)
    col = CHEVRON * (1 - t[..., None] * 0.35) + CHEVRON_DARK * (t[..., None] * 0.35)
    body[..., :3] = col
    body[..., 3] = 255
    right = xx >= 0.5
    body[right & (yy < 0.5)] = 0                  # unused, transparent
    body[right & (yy >= 0.5)] = [*INK, 255]       # the dark recess

    def light(colors, glow):
        im = np.zeros((size, size, 4), dtype=np.float32)
        quad = right & (yy < 0.5)
        # light comes from the top of the chevron and fades downwards; a bright core in the middle
        u = (xx - 0.5) * 2
        v = yy * 2
        t = 1 - v * 0.7 - np.abs(u - 0.5) * 0.4
        if glow:
            t = t + np.exp(-(((u - 0.5) / 0.2) ** 2 + ((v - 0.3) / 0.25) ** 2)) * 0.35
        im[..., :3] = ramp(colors, t)
        im[..., 3] = np.where(quad, 255, 0)
        im[~quad] = 0
        return im

    return (
        Image.fromarray(np.clip(body + 0.5, 0, 255).astype(np.uint8), "RGBA"),
        Image.fromarray(np.clip(light(LIME, True) + 0.5, 0, 255).astype(np.uint8), "RGBA"),
        Image.fromarray(np.clip(light(LIME_OFF, False) + 0.5, 0, 255).astype(np.uint8), "RGBA"),
    )


def iris_texture(jar, size=2048):
    blade = load_model(jar, "iris/iris_blade.obj")

    def paint(fi, pos, n):
        return IRIS if abs(n[2]) > 0.7 else IRIS_SIDE

    img, cover = bake(blade, size, paint, max(3, size // 300), angle=40)
    img = pad(img, cover)
    img[~cover] = IRIS
    return to_image(img)


# --------------------------------------------------------------------------
# the wormhole: JSG plays these sheets frame by frame (14 frames a row) and colours them itself
# --------------------------------------------------------------------------


def swirl_frame(n, phase, base, ink_level, lines=10, ink_px=None, ripple=0.0, flash=0.0, rings=None, soft=None):
    """One frame of the cartoon whirlpool, grey levels 0..255, a disc filling the n x n cell."""
    soft = soft or max(1.5, n / 400)  # anti-aliasing of the ink, in pixels; soft edges keep the JPEG small
    c = (n - 1) / 2
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    dx, dy = xs - c, ys - c
    r = np.hypot(dx, dy) / (n / 2)
    th = np.arctan2(dy, dx)
    # pale water, brighter in the middle
    tone = base + (1 - np.clip(r, 0, 1)) ** 2 * 22 + ripple * 10 * np.sin(r * 18 - phase * 2 * math.pi * 3)
    tone = tone + flash * (255 - tone)
    # ink: log spirals from the middle to the rim, thicker towards the rim
    k = 2.2
    rr = np.maximum(r, 0.02)
    a = (th - k * np.log(rr)) * lines / (2 * math.pi) + phase * lines / (2 * math.pi)
    dist = np.abs(a - np.round(a)) * (2 * math.pi * rr / lines) * (n / 2)  # roughly in pixels
    width = (ink_px or n / 260) * (0.4 + 0.9 * np.clip(r, 0, 1))
    line = np.clip(1 - (dist - width) / soft, 0, 1) * (r > 0.06) * (r < 0.985)
    if rings:
        for rad, w in rings:
            line = np.maximum(line, np.clip(1 - (np.abs(r - rad) * n / 2 - w) / soft, 0, 1))
    out = tone * (1 - line) + ink_level * line
    rim = np.clip(1 - (np.abs(r - 0.985) * n / 2 - n / 300) / soft, 0, 1)
    out = out * (1 - rim) + ink_level * rim
    return np.where(r <= 1.0, out, 255)


def horizon_sheet(size, frames, frame_fn, background=255):
    """Lays frames out like JSG's templates: 14 to a row, the rest of the sheet left blank."""
    sheet = np.full((size, size), background, dtype=np.uint8)
    cell = size / 14
    n = int(math.floor(cell))
    for i in range(frames):
        x = int(round((i % 14) * cell))
        y = int(round((i // 14) * cell))
        f = frame_fn(i, n)
        h = min(n, size - y)
        w = min(n, size - x)
        sheet[y:y + h, x:x + w] = np.clip(f[:h, :w] + 0.5, 0, 255).astype(np.uint8)
    return Image.fromarray(sheet, "L").convert("RGB")


def event_horizon(size=15000, frames=185):
    # one slow turn of the whirlpool by one line spacing over the whole loop, so it repeats seamlessly
    return horizon_sheet(size, frames,
                         lambda i, n: swirl_frame(n, 2 * math.pi * i / frames, base=212, ink_level=26, ripple=0.4))


def kawoosh_frame(i, n, frames=196):
    """The opening: the swirl spins up, flashes white with rings bursting outward,
    darkens while the vortex is out, then settles into the calm whirlpool."""
    t = i / (frames - 1)
    if t < 0.22:  # spinning up
        s = t / 0.22
        return swirl_frame(n, 6 * s, base=150 + 40 * s, ink_level=30, ripple=1.0)
    if t < 0.34:  # the flash
        s = (t - 0.22) / 0.12
        return swirl_frame(n, 6 + 2 * s, base=230, ink_level=60 + 120 * s, flash=min(1.0, s * 1.6),
                           rings=[(0.15 + 0.8 * s, n / 200), (max(0.0, 0.8 * s - 0.25), n / 260)])
    if t < 0.58:  # the vortex is out: the face goes dark
        s = (t - 0.34) / 0.24
        return swirl_frame(n, 8 + 3 * s, base=95 + 25 * math.sin(s * math.pi), ink_level=18, ripple=1.0,
                           rings=[(0.35 + 0.6 * ((s * 3) % 1), n / 220)])
    if t < 0.75:  # coming back
        s = (t - 0.58) / 0.17
        return swirl_frame(n, 11 + 2 * s, base=110 + 95 * s, ink_level=24, ripple=1.0 - 0.6 * s)
    s = (t - 0.75) / 0.25  # settling
    return swirl_frame(n, 13 + s, base=205 + 7 * s, ink_level=26, ripple=0.4)


def kawoosh(size=10800, frames=196):
    return horizon_sheet(size, frames, lambda i, n: kawoosh_frame(i, n, frames), background=250)


# --------------------------------------------------------------------------
# the pack
# --------------------------------------------------------------------------

DESCRIPTION = "Stargate Infinity look for JSG's Milky Way gate"


def save(img, out_dir, rel, quality=None):
    path = os.path.join(out_dir, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if rel.endswith(".jpg"):
        img.convert("RGB").save(path, quality=quality or 92, optimize=True)
    else:
        img.save(path, optimize=True)
    return path


# JSG's own sheets are 15000 and 10800 pixels square. Line art needs far fewer pixels than its
# photographic frames, so these are smaller: 500 and 400 pixels a frame. The frames sit on the
# same 14-wide grid, at the same fractions of the sheet. --full makes them JSG's size.
HORIZON_SIZE, KAWOOSH_SIZE = 7000, 5600
HORIZON_FULL, KAWOOSH_FULL = 15000, 10800


def build(jar_path, out_dir, small=False, full=False):
    jar = zipfile.ZipFile(jar_path)
    files = []
    mw = TESR + "milkyway/"
    ring_size = 1024 if small else 2048
    for suffix, tint in BIOME_TINTS.items():
        print("gatering" + suffix)
        files.append(save(gate_ring_texture(jar, ring_size, tint), out_dir, mw + f"gatering{suffix}.jpg"))
    body, lit, unlit = chevron_textures()
    for suffix in BIOME_TINTS:
        files.append(save(body, out_dir, mw + f"chevron{suffix}.png"))
        files.append(save(lit, out_dir, mw + f"chevron_light{suffix}.png"))
        files.append(save(unlit, out_dir, mw + f"chevron_light_off{suffix}.png"))
    print("iris")
    files.append(save(iris_texture(jar, 1024 if small else 2048), out_dir, TESR + "iris/iris_blade.jpg"))
    print("event horizon")
    horizon_size = 1400 if small else HORIZON_FULL if full else HORIZON_SIZE
    kawoosh_size = 1120 if small else KAWOOSH_FULL if full else KAWOOSH_SIZE
    files.append(save(event_horizon(horizon_size), out_dir, TESR + "event_horizon_animated_template.jpg", 82))
    print("kawoosh")
    files.append(save(kawoosh(kawoosh_size), out_dir, TESR + "event_horizon_animated_template_kawoosh.jpg", 82))
    with open(os.path.join(out_dir, "pack.mcmeta"), "w") as f:
        json.dump({"pack": {"pack_format": 15, "description": DESCRIPTION}}, f, indent=2)
        f.write("\n")
    # the pack's icon: the gate drawn with these textures
    import preview
    icon = os.path.join(out_dir, "pack.png")
    preview.render(jar_path, out_dir, icon, "open", 512)
    Image.open(icon).resize((128, 128), Image.LANCZOS).save(icon, optimize=True)
    files.append(icon)
    return files


def make_zip(out_dir, zip_path, extra=()):
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _, names in os.walk(out_dir):
            for name in sorted(names):
                full = os.path.join(root, name)
                rel = os.path.relpath(full, out_dir).replace(os.sep, "/")
                # jpegs are already compressed
                z.write(full, rel, compress_type=zipfile.ZIP_STORED if name.endswith(".jpg") else zipfile.ZIP_DEFLATED)
        for src, rel in extra:
            z.write(src, rel)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    small = "--small" in sys.argv
    full = "--full" in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    build(args[0], args[1], small, full)
    if len(args) > 2:
        here = os.path.dirname(os.path.abspath(__file__))
        make_zip(args[1], args[2], [(os.path.join(here, "..", "..", "LICENSE"), "LICENSE.txt")])
        print("wrote", args[2])
