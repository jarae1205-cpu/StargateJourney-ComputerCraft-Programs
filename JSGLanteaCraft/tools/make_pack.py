"""
Builds the LanteaCraft look resource pack for Just Stargate Mod (JSG) 1.20.1.

After the gate of LanteaCraft, the stargate mod for Minecraft 1.7.10: a charcoal
ring with a toothed rim and pale carved glyphs, chevrons that light amber, and a
deep wormhole flecked with white foam.

Every texture is drawn here. Like the Infinity pack (../JSGInfinity), the script
only reads JSG's gate models to learn where each part of the gate sits on its
texture; it uses that pack's model reader, baker and wormhole sheet layout.

    python3 make_pack.py <jsg-1.20.1-x.jar> <output dir> [zip file] [--small]

Needs Pillow and numpy.
"""
import json
import math
import os
import random
import sys
import zipfile

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "JSGInfinity", "tools"))
from make_pack import TESR, bake, load_model, pad, ramp, rgb, save, to_image, horizon_sheet, make_zip  # noqa: E402

Image.MAX_IMAGE_PIXELS = None

# --------------------------------------------------------------------------
# colours. JSG lights its gate dimly (it drew the Infinity pack's ring at about
# 40% of the texture's brightness), so these are lighter than they come out.
# --------------------------------------------------------------------------

GROOVE = rgb(0x2A2B2F)     # the dark lines along every fold
RIM = rgb(0x8C8E94)        # the raised teeth round the rim
NOTCH = rgb(0x3C3D42)      # the gaps between them
STONE = rgb(0x76787E)      # front faces
SIDE = rgb(0x5E6066)       # sides turned outward
SHADOW = rgb(0x46484D)     # backs, undersides, sides turned inward
TRACK = rgb(0x66686E)      # the symbol track
GLYPH = rgb(0xC6C9D0)      # carved glyphs, pale
GLYPH_SIDE = rgb(0x8A8D94)
CHEVRON = rgb(0x4A4B50)    # chevron body
CHEVRON_DARK = rgb(0x2E2F33)
AMBER = [rgb(0x7A4A00), rgb(0xD89A10), rgb(0xFFC21F), rgb(0xFFF0B0)]
AMBER_OFF = [rgb(0x18140A), rgb(0x2C2410), rgb(0x3E3216)]

# JSG swaps in these textures in some biomes; the charcoal gate gets a light tint for each
BIOME_TINTS = {
    "": None,
    "_aged": (rgb(0x8C7A5A), 0.20),
    "_frost": (rgb(0xE8F2FF), 0.30),
    "_mossy": (rgb(0x5E7A40), 0.22),
    "_sooty": (rgb(0x141518), 0.25),
}


def gate_ring_texture(jar, size=2048, tint=None):
    """gatering.jpg: the outer ring (gate.obj) and the turning symbol ring (ring.obj) share it."""
    gate = load_model(jar, "milkyway/gate.obj")
    ring = load_model(jar, "milkyway/ring.obj")

    def gate_paint(fi, pos, n):
        r = np.hypot(pos[:, 0], pos[:, 1])
        if n[2] > 0.7:
            # front: a toothed rim, raised blocks with dark gaps, round the outer edge
            ang = np.degrees(np.arctan2(pos[:, 1], pos[:, 0])) % 360
            tooth = (np.floor(ang / 2.5) % 2 == 0)
            rim = r > 4.75
            col = np.where((rim & tooth)[:, None], RIM, np.where(rim[:, None], NOTCH, STONE))
            return col
        if n[2] < -0.7:
            return SHADOW
        radial = (pos[:, 0] * n[0] + pos[:, 1] * n[1]) / np.maximum(r, 1e-6)
        return np.where((radial > 0)[:, None], SIDE, SHADOW)

    # the glyphs are raised shapes whose tops share the upper right of the texture
    glyph = (ring.uv_centers[:, 0] > 0.53) & (ring.uv_centers[:, 1] > 0.62)

    def ring_paint(fi, pos, n):
        if glyph[fi]:
            return GLYPH if n[2] > 0.9 else GLYPH_SIDE
        if n[2] > 0.7:
            return np.where((pos[:, 2] > 0.182)[:, None], STONE, TRACK)
        if n[2] < -0.7:
            return SHADOW
        return SIDE

    w = max(1, size // 1024)
    img_g, cov_g = bake(gate, size, gate_paint, w + 1, ink=GROOVE)
    img_r, cov_r = bake(ring, size, ring_paint, w, ink=GROOVE)
    img = np.where(cov_r[..., None], img_r, img_g)
    cover = cov_g | cov_r
    img = pad(img, cover)
    img[~cover] = STONE
    # a little grain, like worn stone
    rnd = np.random.default_rng(7)
    img = img + rnd.normal(0, 4, img.shape[:2])[..., None]
    if tint is not None:
        col, amount = tint
        img = img * (1 - amount) + col * amount
    return to_image(img)


def chevron_textures(size=256):
    """chevron.png (body), chevron_light.png (lit amber) and chevron_light_off.png (dark)."""
    yy, xx = np.mgrid[0:size, 0:size] / size
    body = np.zeros((size, size, 4), dtype=np.float32)
    t = np.clip((yy - 0.15) / 0.85, 0, 1)
    body[..., :3] = CHEVRON * (1 - t[..., None] * 0.4) + CHEVRON_DARK * (t[..., None] * 0.4)
    body[..., 3] = 255
    right = xx >= 0.5
    body[right & (yy < 0.5)] = 0                    # unused, transparent
    body[right & (yy >= 0.5)] = [*GROOVE, 255]      # the dark recess

    def light(colors, glow):
        im = np.zeros((size, size, 4), dtype=np.float32)
        quad = right & (yy < 0.5)
        u = (xx - 0.5) * 2
        v = yy * 2
        # LanteaCraft's chevrons are faceted: the left face lit brighter than the right
        t = 0.95 - v * 0.55 - np.where(u < 0.5, 0.0, 0.22)
        if glow:
            t = t + np.exp(-(((u - 0.4) / 0.22) ** 2 + ((v - 0.3) / 0.25) ** 2)) * 0.3
        im[..., :3] = ramp(colors, t)
        im[..., 3] = np.where(quad, 255, 0)
        im[~quad] = 0
        return im

    to = lambda a: Image.fromarray(np.clip(a + 0.5, 0, 255).astype(np.uint8), "RGBA")
    return to(body), to(light(AMBER, True)), to(light(AMBER_OFF, False))


# --------------------------------------------------------------------------
# the wormhole: JSG plays these sheets frame by frame (14 frames a row) and tints them
# blue itself, so they are grey: dark water, white flecks of foam
# --------------------------------------------------------------------------

def foam(count, seed=29):
    rnd = random.Random(seed)
    out = []
    for _ in range(count):
        out.append((rnd.random(), rnd.uniform(0, math.tau), rnd.uniform(-0.5, 0.5), rnd.randrange(2, 6),
                    rnd.choice((255, 235, 215))))
    return out


FOAM = foam(260)


def flecked_frame(n, phase, base=62, density=1.0, flash=0.0, burst=None):
    """One frame: dark water a little lighter in the middle, and flecks of foam that drift
    outwards from the middle to the rim once over the loop (phase 0..1), so the loop is seamless."""
    c = (n - 1) / 2
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    r = np.hypot(xs - c, ys - c) / (n / 2)
    tone = base + (1 - np.clip(r, 0, 1)) ** 2 * 26 + 6 * np.sin(r * 20 - phase * 2 * math.pi * 4)
    tone = tone + flash * (250 - tone)
    if burst is not None:  # a bright ring running out from the middle
        tone = np.maximum(tone, 250 * np.clip(1 - np.abs(r - burst) * 9, 0, 1))
    img = Image.fromarray(np.clip(np.where(r <= 1.0, tone, 255), 0, 255).astype(np.uint8), "L")
    d = ImageDraw.Draw(img)
    s = n / 128  # strokes scale with the frame
    count = int(len(FOAM) * min(1.0, density))
    for r0, ang, tilt, length, shade in FOAM[:count]:
        rr = ((r0 + phase) % 1.0)
        rad = math.sqrt(rr) * 0.94 * n / 2
        a = ang + phase * 0.6
        cx, cy = c + rad * math.cos(a), c + rad * math.sin(a)
        along = a + math.pi / 2 + tilt
        fade = min(1.0, rr / 0.08, (1 - rr) / 0.12)  # flecks come and go softly
        level = int(base + (shade - base) * fade)
        x1, y1 = cx + math.cos(along) * length * s * 1.4, cy + math.sin(along) * length * s * 1.4
        d.line([(cx, cy), (x1, y1)], fill=level, width=max(1, int(round(s * 1.3))))
    return np.asarray(img, dtype=np.float32)


def event_horizon(size, frames=185):
    return horizon_sheet(size, frames, lambda i, n: flecked_frame(n, i / frames))


def kawoosh_frame(i, n, frames=196):
    """The opening: a white flash with a ring bursting outwards, churning foam, then the
    water calms and darkens into the first frame of the open wormhole."""
    t = i / (frames - 1)
    if t < 0.15:
        s = t / 0.15
        return flecked_frame(n, 0.0, base=90, density=0.3, flash=s, burst=0.1 + 0.9 * s)
    if t < 0.6:
        s = (t - 0.15) / 0.45
        return flecked_frame(n, s * 0.5, base=200 - 110 * s, density=1.0, flash=max(0.0, 0.6 - s))
    s = (t - 0.6) / 0.4
    return flecked_frame(n, 0.5 + 0.5 * s, base=90 - 28 * s)


# --------------------------------------------------------------------------
# the pack
# --------------------------------------------------------------------------

DESCRIPTION = "LanteaCraft look for JSG's Milky Way gate"
HORIZON_SIZE, KAWOOSH_SIZE = 7000, 5600


def build(jar_path, out_dir, small=False):
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
    print("event horizon")
    files.append(save(event_horizon(1400 if small else HORIZON_SIZE), out_dir,
                      TESR + "event_horizon_animated_template.jpg", 84))
    print("kawoosh")
    files.append(save(horizon_sheet(1120 if small else KAWOOSH_SIZE, 196, lambda i, n: kawoosh_frame(i, n), background=250),
                      out_dir, TESR + "event_horizon_animated_template_kawoosh.jpg", 84))
    with open(os.path.join(out_dir, "pack.mcmeta"), "w") as f:
        json.dump({"pack": {"pack_format": 15, "description": DESCRIPTION}}, f, indent=2)
        f.write("\n")
    import preview  # the Infinity pack's renderer, for the pack's icon
    icon = os.path.join(out_dir, "pack.png")
    preview.render(jar_path, out_dir, icon, "open", 512)
    Image.open(icon).resize((128, 128), Image.LANCZOS).save(icon, optimize=True)
    files.append(icon)
    return files


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    small = "--small" in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    build(args[0], args[1], small)
    if len(args) > 2:
        make_zip(args[1], args[2], [(os.path.join(HERE, "..", "..", "LICENSE"), "LICENSE.txt")])
        print("wrote", args[2])
