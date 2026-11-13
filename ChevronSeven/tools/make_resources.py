"""
Generates Chevron Seven's textures and data files: the gate textures, the 39 gate symbols,
the DHD, item icons, blockstates, models, loot tables, recipes, tags, the kawoosh damage type
and the English text.

    python3 tools/make_resources.py        (run from ChevronSeven/; needs Pillow)

Every texture and symbol is drawn here from scratch.
"""
import json
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

MOD = "chevron7"
RES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "main", "resources")
ASSETS = os.path.join(RES, "assets", MOD)
DATA = os.path.join(RES, "data", MOD)


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def save(img, kind, name):
    path = os.path.join(ASSETS, "textures", kind, name + ".png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


def clamp(v):
    return max(0, min(255, int(v)))


def noise_tile(w, h, base, spread, seed, grain=1):
    """Value noise with a few octaves, tileable, as an RGBA image tinted with base."""
    rnd = random.Random(seed)
    img = Image.new("RGBA", (w, h))
    px = img.load()
    layers = []
    for cells in (4, 8, 16):
        grid = [[rnd.random() for _ in range(cells)] for _ in range(cells)]
        layers.append((cells, grid))
    for y in range(h):
        for x in range(w):
            v = 0.0
            for i, (cells, grid) in enumerate(layers):
                fx, fy = x / w * cells, y / h * cells
                x0, y0 = int(fx) % cells, int(fy) % cells
                x1, y1 = (x0 + 1) % cells, (y0 + 1) % cells
                tx, ty = fx - int(fx), fy - int(fy)
                tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
                a = grid[y0][x0] * (1 - tx) + grid[y0][x1] * tx
                b = grid[y1][x0] * (1 - tx) + grid[y1][x1] * tx
                v += (a * (1 - ty) + b * ty) / (2 ** i)
            v = v / 1.75 - 0.5 + (rnd.random() - 0.5) * 0.25 * grain
            px[x, y] = tuple(clamp(c + v * spread) for c in base) + (255,)
    return img


# --------------------------------------------------------------------------
# the gate
# --------------------------------------------------------------------------

def gate_stone():
    """The outer ring: blue-grey stone. u runs along the ring, v from inside (1) to outside (0)."""
    img = noise_tile(64, 64, (104, 108, 116), 70, 7)
    d = ImageDraw.Draw(img)
    # two engraved rings and a raised lip at each edge
    for y, col in ((3, (70, 72, 80)), (4, (140, 144, 152)), (20, (66, 68, 76)), (21, (128, 132, 140)),
                   (42, (66, 68, 76)), (43, (128, 132, 140)), (59, (70, 72, 80)), (60, (140, 144, 152))):
        d.line([(0, y), (63, y)], fill=col + (255,))
    # a seam between segments
    d.line([(0, 0), (0, 63)], fill=(62, 64, 72, 255))
    return img


def gate_track():
    """The turning symbol track: darker, smoother stone."""
    img = noise_tile(64, 64, (78, 80, 88), 40, 11)
    d = ImageDraw.Draw(img)
    d.line([(0, 0), (0, 63)], fill=(46, 48, 54, 255))
    d.line([(63, 0), (63, 63)], fill=(96, 98, 106, 255))
    d.line([(0, 2), (63, 2)], fill=(52, 54, 60, 255))
    d.line([(0, 61), (63, 61)], fill=(52, 54, 60, 255))
    return img


def chevron():
    """A V pointing to the centre of the gate; the renderer tints it orange when lit."""
    s = 64
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    outer = [(4, 6), (60, 6), (32, 58)]
    inner = [(18, 6), (46, 6), (32, 36)]
    d.polygon(outer, fill=(235, 235, 235, 255))
    d.polygon(inner, fill=(0, 0, 0, 0))
    # bevel: a lighter top edge, darker inner edge
    d.line([(4, 6), (18, 6)], fill=(255, 255, 255, 255), width=3)
    d.line([(46, 6), (60, 6)], fill=(255, 255, 255, 255), width=3)
    d.line([(18, 7), (32, 36), (46, 7)], fill=(170, 170, 170, 255), width=2)
    return img


def event_horizon():
    """Shimmering blue water, sampled by the renderer with a swirl."""
    s = 128
    img = Image.new("RGBA", (s, s))
    px = img.load()
    rnd = random.Random(3)
    waves = [(rnd.uniform(0.04, 0.16), rnd.uniform(0, math.tau), rnd.uniform(0, math.tau)) for _ in range(9)]
    for y in range(s):
        for x in range(s):
            v = 0.0
            for f, ph, ang in waves:
                v += math.sin((x * math.cos(ang) + y * math.sin(ang)) * f + ph)
            v = v / len(waves)
            caustic = abs(v) ** 0.5
            light = 1 - caustic
            r = 70 + 150 * light ** 3
            g = 120 + 120 * light ** 2
            b = 205 + 50 * light
            px[x, y] = (clamp(r), clamp(g), clamp(b), 225)
    return img.filter(ImageFilter.GaussianBlur(0.6))


def iris():
    """Brushed metal, light and neutral: the renderer tints it for each look and draws the blade edges."""
    img = noise_tile(32, 32, (222, 224, 228), 26, 21, grain=2)
    d = ImageDraw.Draw(img)
    for x in range(0, 32, 4):
        d.line([(x, 0), (x + 6, 31)], fill=(236, 238, 242, 255))
    return img


# --------------------------------------------------------------------------
# gate looks: each look has its own ring, symbol track and event horizon textures;
# the renderer adds its chevron, glyph and iris colours (GateLook.java). "sg1" is the
# original look and uses the plain gate_stone / gate_track / event_horizon textures.
# --------------------------------------------------------------------------

LOOKS = {
    # id: stone colour, track colour, horizon (dark, middle, bright), extras
    "movie": dict(stone=(92, 84, 76), track=(66, 62, 58), horizon=((24, 52, 150), (90, 140, 240), (220, 236, 255))),
    "origins": dict(stone=(142, 120, 88), track=(112, 94, 68), horizon=((70, 110, 170), (150, 190, 230), (240, 246, 255)), wear=True),
    "continuum": dict(stone=(176, 186, 196), track=(142, 152, 164), horizon=((60, 130, 200), (150, 205, 245), (245, 252, 255)), frost=True),
    "ark": dict(stone=(178, 142, 64), track=(140, 108, 44), horizon=((150, 90, 10), (230, 170, 50), (255, 240, 170))),
    "atlantis": dict(stone=(92, 108, 132), track=(66, 80, 104), horizon=((20, 70, 180), (70, 150, 250), (210, 235, 255))),
    "universe": dict(stone=(60, 62, 68), track=(44, 46, 52), horizon=((40, 70, 140), (150, 180, 240), (250, 252, 255))),
    "infinity": dict(stone=(196, 204, 216), track=(166, 174, 188), cartoon=True),
    "ori": dict(stone=(44, 44, 50), track=(32, 32, 38), horizon=((30, 50, 130), (140, 170, 240), (250, 250, 255))),
    "tollan": dict(stone=(122, 142, 130), track=(96, 114, 104), horizon=((20, 110, 60), (80, 200, 120), (210, 255, 220))),
    "goauld": dict(stone=(132, 102, 62), track=(100, 76, 44), horizon=((150, 70, 10), (230, 140, 40), (255, 225, 150))),
    "wraith": dict(stone=(72, 60, 84), track=(54, 44, 64), horizon=((70, 20, 120), (150, 70, 220), (235, 200, 255))),
    "crimson": dict(stone=(84, 58, 58), track=(64, 42, 42), horizon=((120, 10, 10), (220, 50, 40), (255, 200, 170))),
}


def look_stone(spec, seed):
    base = spec["stone"]
    img = noise_tile(64, 64, base, 34 if spec.get("cartoon") else 70, 7 + seed)
    d = ImageDraw.Draw(img)
    dark = tuple(clamp(c * 0.64) for c in base) + (255,)
    light = tuple(clamp(c * 1.3) for c in base) + (255,)
    if spec.get("cartoon"):
        # flat colour with black ink outlines, like the animated series
        ink = (24, 26, 34, 255)
        for y in (1, 2, 61, 62):
            d.line([(0, y), (63, y)], fill=ink)
        for y in (21, 42):
            d.line([(0, y), (63, y)], fill=(120, 128, 142, 255))
        d.line([(0, 0), (0, 63)], fill=ink, width=2)
        return img
    for y, col in ((3, dark), (4, light), (20, dark), (21, light), (42, dark), (43, light), (59, dark), (60, light)):
        d.line([(0, y), (63, y)], fill=col)
    d.line([(0, 0), (0, 63)], fill=dark)
    rnd = random.Random(40 + seed)
    px = img.load()
    if spec.get("wear"):
        # chips and grime on old stone
        for _ in range(90):
            x, y = rnd.randrange(64), rnd.randrange(64)
            c = px[x, y]
            px[x, y] = tuple(clamp(v * 0.62) for v in c[:3]) + (255,)
    if spec.get("frost"):
        for _ in range(160):
            x, y = rnd.randrange(64), rnd.randrange(64)
            px[x, y] = (236, 244, 252, 255)
    return img


def look_track(spec, seed):
    base = spec["track"]
    img = noise_tile(64, 64, base, 24 if spec.get("cartoon") else 40, 11 + seed)
    d = ImageDraw.Draw(img)
    edge = (24, 26, 34, 255) if spec.get("cartoon") else tuple(clamp(c * 0.6) for c in base) + (255,)
    d.line([(0, 0), (0, 63)], fill=edge, width=2 if spec.get("cartoon") else 1)
    d.line([(63, 0), (63, 63)], fill=tuple(clamp(c * 1.2) for c in base) + (255,))
    d.line([(0, 2), (63, 2)], fill=edge)
    d.line([(0, 61), (63, 61)], fill=edge)
    return img


def look_horizon(spec, seed):
    """Water like the original horizon, in the look's colours."""
    if spec.get("cartoon"):
        return cartoon_horizon()
    dark, mid, bright = spec["horizon"]
    s = 128
    img = Image.new("RGBA", (s, s))
    px = img.load()
    rnd = random.Random(3)  # same waves as the original, so all looks move alike
    waves = [(rnd.uniform(0.04, 0.16), rnd.uniform(0, math.tau), rnd.uniform(0, math.tau)) for _ in range(9)]
    for y in range(s):
        for x in range(s):
            v = 0.0
            for f, ph, ang in waves:
                v += math.sin((x * math.cos(ang) + y * math.sin(ang)) * f + ph)
            light = 1 - abs(v / len(waves)) ** 0.5
            col = [dark[i] + (mid[i] - dark[i]) * light + (bright[i] - mid[i]) * light ** 4 for i in range(3)]
            px[x, y] = tuple(clamp(c) for c in col) + (228,)
    return img.filter(ImageFilter.GaussianBlur(0.6))


def cartoon_horizon():
    """Flat bright cyan with white crescent streaks, like the animated series' wormhole."""
    s = 128
    img = Image.new("RGBA", (s, s), (38, 196, 232, 236))
    d = ImageDraw.Draw(img)
    rnd = random.Random(17)
    # a lighter middle
    for r in range(56, 0, -4):
        t = 1 - r / 56
        d.ellipse([64 - r, 64 - r, 64 + r, 64 + r], fill=(clamp(38 + 60 * t), clamp(196 + 30 * t), clamp(232 + 18 * t), 236))
    for _ in range(46):
        cx, cy = rnd.uniform(0, s), rnd.uniform(0, s)
        r = rnd.uniform(6, 22)
        start = rnd.uniform(0, 360)
        d.arc([cx - r, cy - r, cx + r, cy + r], start, start + rnd.uniform(40, 110), fill=(246, 252, 255, 255), width=rnd.choice((2, 3, 3, 4)))
    return img


def look_crystal_icon():
    s = 64
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(32, 4), (48, 22), (40, 58), (24, 58), (16, 22)], fill=(150, 96, 220, 255), outline=(70, 36, 120, 255))
    d.polygon([(32, 4), (40, 22), (32, 58), (24, 22)], fill=(196, 150, 250, 255))
    d.line([(16, 22), (48, 22)], fill=(90, 50, 150, 255), width=2)
    for x, col in ((22, (240, 140, 40)), (32, (80, 200, 240)), (42, (120, 220, 120))):
        d.ellipse([x - 3, 34, x + 3, 40], fill=col + (255,))
    return img.resize((16, 16), Image.LANCZOS)


# --------------------------------------------------------------------------
# the 39 symbols: little constellations, white on transparent, 32x32 each, 8 per row
# --------------------------------------------------------------------------

def glyph(symbol):
    big = 128  # drawn large, then scaled down
    img = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(img)
    w = 9
    if symbol == 0:
        # point of origin: a seven-pointed star in a ring
        c = big / 2
        d.ellipse([c - 50, c - 50, c + 50, c + 50], outline=255, width=w)
        pts = []
        for i in range(14):
            r = 34 if i % 2 == 0 else 15
            a = math.pi * 2 * i / 14 - math.pi / 2
            pts.append((c + r * math.cos(a), c + r * math.sin(a)))
        d.polygon(pts, fill=255)
    else:
        rnd = random.Random(1000 + symbol * 7919)
        count = 3 + symbol % 4
        pts = []
        tries = 0
        while len(pts) < count and tries < 500:
            tries += 1
            p = (rnd.uniform(18, big - 18), rnd.uniform(18, big - 18))
            if all(math.dist(p, q) > 34 for q in pts):
                pts.append(p)
        # connect each point to the nearest earlier one, then close a loop on some symbols
        for i in range(1, len(pts)):
            j = min(range(i), key=lambda k: math.dist(pts[i], pts[k]))
            d.line([pts[i], pts[j]], fill=255, width=w)
        if symbol % 3 == 0 and len(pts) > 3:
            d.line([pts[-1], pts[0]], fill=255, width=w)
        for i, p in enumerate(pts):
            r = 13 if i == 0 else 9
            if symbol % 5 == 2 and i == len(pts) - 1:
                d.ellipse([p[0] - 15, p[1] - 15, p[0] + 15, p[1] + 15], outline=255, width=6)
            else:
                d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=255)
    small = img.resize((32, 32), Image.LANCZOS)
    out = Image.new("RGBA", (32, 32), (255, 255, 255, 0))
    out.putalpha(small.point(lambda v: 255 if v > 90 else 0))
    return out


def glyph_atlas():
    atlas = Image.new("RGBA", (256, 160), (0, 0, 0, 0))
    for s in range(39):
        atlas.paste(glyph(s), ((s % 8) * 32, (s // 8) * 32))
    return atlas


# --------------------------------------------------------------------------
# DHD and icons
# --------------------------------------------------------------------------

def dhd_side():
    img = noise_tile(16, 16, (150, 118, 92), 50, 31, grain=2)
    d = ImageDraw.Draw(img)
    d.line([(0, 3), (15, 3)], fill=(108, 82, 62, 255))
    d.line([(0, 12), (15, 12)], fill=(108, 82, 62, 255))
    d.rectangle([5, 6, 10, 9], outline=(176, 142, 110, 255))
    return img


def dhd_bottom():
    return noise_tile(16, 16, (120, 94, 74), 40, 37, grain=2)


def dhd_top():
    s = 64
    img = noise_tile(s, s, (120, 94, 74), 40, 41, grain=2)
    d = ImageDraw.Draw(img)
    c = s / 2
    for ring, count, r in ((0, 20, 26), (1, 19, 17)):
        for i in range(count):
            a = math.tau * i / count
            x, y = c + r * math.sin(a), c - r * math.cos(a)
            d.rectangle([x - 2, y - 2, x + 2, y + 2], fill=(176, 150, 120, 255), outline=(70, 52, 40, 255))
    d.ellipse([c - 9, c - 9, c + 9, c + 9], fill=(70, 20, 14, 255))
    d.ellipse([c - 7, c - 7, c + 7, c + 7], fill=(196, 44, 26, 255))
    d.ellipse([c - 5, c - 6, c - 1, c - 2], fill=(240, 120, 100, 255))
    return img


def gate_icon():
    s = 64
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = s / 2
    d.ellipse([c - 21, c - 21, c + 21, c + 21], fill=(110, 170, 235, 255))
    d.ellipse([c - 14, c - 14, c + 6, c + 6], fill=(170, 210, 250, 255))
    d.ellipse([c - 30, c - 30, c + 30, c + 30], outline=(96, 100, 110, 255), width=10)
    d.ellipse([c - 30, c - 30, c + 30, c + 30], outline=(60, 62, 70, 255), width=2)
    d.ellipse([c - 21, c - 21, c + 21, c + 21], outline=(70, 72, 80, 255), width=2)
    for i in range(9):
        a = math.tau * i / 9
        x, y = c + 28 * math.sin(a), c - 28 * math.cos(a)
        d.regular_polygon((x, y, 5), 3, rotation=math.degrees(-a) + 180, fill=(240, 150, 40, 255))
    return img.resize((16, 16), Image.LANCZOS)


def iris_icon():
    s = 64
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = s / 2
    d.ellipse([c - 29, c - 29, c + 29, c + 29], fill=(150, 154, 160, 255), outline=(70, 72, 78, 255), width=3)
    for i in range(10):
        a = math.tau * i / 10
        d.line([(c, c), (c + 28 * math.sin(a + 0.5), c - 28 * math.cos(a + 0.5))], fill=(96, 100, 108, 255), width=2)
    d.ellipse([c - 4, c - 4, c + 4, c + 4], fill=(80, 84, 90, 255))
    return img.resize((16, 16), Image.LANCZOS)


def address_book_icon():
    s = 64
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([10, 6, 54, 58], fill=(52, 70, 120, 255), outline=(26, 34, 60, 255), width=3)
    d.rectangle([12, 52, 54, 56], fill=(228, 220, 200, 255))
    c = (32, 28)
    d.ellipse([c[0] - 14, c[1] - 14, c[0] + 14, c[1] + 14], outline=(200, 204, 214, 255), width=5)
    d.ellipse([c[0] - 7, c[1] - 7, c[0] + 7, c[1] + 7], fill=(120, 180, 240, 255))
    for i in range(7):
        a = math.tau * i / 7
        x, y = c[0] + 15 * math.sin(a), c[1] - 15 * math.cos(a)
        d.ellipse([x - 2.5, y - 2.5, x + 2.5, y + 2.5], fill=(240, 150, 40, 255))
    return img.resize((16, 16), Image.LANCZOS)


def particle():
    return gate_stone().resize((16, 16), Image.LANCZOS)


# --------------------------------------------------------------------------
# data
# --------------------------------------------------------------------------

LANG = {
    "itemGroup.chevron7": "Chevron Seven",
    "block.chevron7.stargate": "Stargate",
    "block.chevron7.gate_frame": "Stargate",
    "block.chevron7.dhd": "Dial Home Device",
    "item.chevron7.iris": "Gate Iris",
    "item.chevron7.address_book": "Gate Address Book",
    "message.chevron7.planets": "Planet gates:",
    "message.chevron7.planets_hint": "Dial one from any gate. The first wormhole to a planet finds its gate, near 8, 6.",
    "message.chevron7.no_planets": "No planets with gates (planets come from mods such as Ad Astra)",
    "death.attack.chevron7.kawoosh": "%1$s was vaporised by a kawoosh",
    "death.attack.chevron7.kawoosh.player": "%1$s was vaporised by a kawoosh while fighting %2$s",
    "message.chevron7.no_room": "Not enough room: a stargate needs a clear 7 by 7 space",
    "message.chevron7.address": "This gate's address: %s",
    "message.chevron7.iris_installed": "Iris fitted",
    "message.chevron7.iris_already": "This gate already has an iris",
    "message.chevron7.no_iris": "That gate has no iris",
    "message.chevron7.iris_closing": "Closing the iris",
    "message.chevron7.iris_opening": "Opening the iris",
    "message.chevron7.no_gate": "No stargate within 16 blocks of this DHD",
    "message.chevron7.not_a_gate": "There is no stargate there",
    "message.chevron7.dialing": "Dialing %s: %s",
    "message.chevron7.list": "%s stargates:",
    "feedback.chevron7.symbol_encoded": "Symbol encoded",
    "feedback.chevron7.connected": "Wormhole established",
    "feedback.chevron7.disconnected": "Wormhole closed",
    "feedback.chevron7.autoclose": "Wormhole closed: it was open too long",
    "feedback.chevron7.reset": "Dialing stopped",
    "feedback.chevron7.nothing_to_close": "There is nothing to close",
    "feedback.chevron7.symbol_in_address": "That symbol is already in the address",
    "feedback.chevron7.symbol_out_of_bounds": "There is no such symbol",
    "feedback.chevron7.incomplete_address": "The address is incomplete",
    "feedback.chevron7.invalid_address": "No stargate has that address",
    "feedback.chevron7.target_busy": "The other gate is busy",
    "feedback.chevron7.self_dial": "A gate can't dial itself",
    "feedback.chevron7.already_connected": "The gate is already connected",
    "feedback.chevron7.stargate_destroyed": "The other gate was destroyed",
    "feedback.chevron7.connection_lost": "The connection was lost",
    "feedback.chevron7.interrupted_by_incoming_connection": "Interrupted by an incoming wormhole",
    "feedback.chevron7.address_full": "The address is already complete",
    "feedback.chevron7.only_the_dialing_gate_can_close": "Only the dialing gate can close the wormhole",
    "screen.chevron7.dhd": "Dial Home Device",
    "screen.chevron7.no_gate": "No stargate within 16 blocks",
    "screen.chevron7.this_gate": "This gate: %s",
    "screen.chevron7.dialing": "Dialing %s",
    "screen.chevron7.state.idle": "Idle",
    "screen.chevron7.state.dialing": "Dialing",
    "screen.chevron7.state.outgoing": "Wormhole open",
    "screen.chevron7.state.incoming": "Incoming wormhole",
    "screen.chevron7.state.closing": "Closing",
    "screen.chevron7.state.resetting": "Dial failed",
    "screen.chevron7.iris_open": "Iris open",
    "screen.chevron7.iris_closed": "Iris shut",
    "screen.chevron7.point_of_origin": "Point of origin (dial it last)",
    "screen.chevron7.symbol": "Symbol %s",
    "screen.chevron7.gate_n": "Gate %s of %s",
    "message.chevron7.bad_direction": "The direction is north, east, south or west",
    "message.chevron7.field_built": "Built a gate field of %s gates",
    "item.chevron7.look_crystal": "Gate Look Crystal",
    "message.chevron7.look": "Gate look: %s",
    "message.chevron7.looks": "Gate looks: %s",
    "message.chevron7.bad_look": "There is no look called %s",
    "message.chevron7.platform_built": "Built a gate on a platform",
    "message.chevron7.gate_room_built": "Built a gate room",
    "look.chevron7.sg1": "SG-1",
    "look.chevron7.movie": "Movie",
    "look.chevron7.origins": "Origins",
    "look.chevron7.continuum": "Continuum",
    "look.chevron7.ark": "Ark of Truth",
    "look.chevron7.atlantis": "Atlantis",
    "look.chevron7.universe": "Universe",
    "look.chevron7.infinity": "Infinity",
    "look.chevron7.ori": "Ori",
    "look.chevron7.tollan": "Tollan",
    "look.chevron7.goauld": "Goa'uld",
    "look.chevron7.wraith": "Wraith",
    "look.chevron7.crimson": "Crimson",
}


def data_files():
    # blockstates and models
    write_json(os.path.join(ASSETS, "blockstates", "stargate.json"), {"variants": {"": {"model": "chevron7:block/stargate"}}})
    write_json(os.path.join(ASSETS, "blockstates", "gate_frame.json"), {"variants": {"": {"model": "chevron7:block/gate_frame"}}})
    write_json(os.path.join(ASSETS, "models", "block", "stargate.json"), {"textures": {"particle": "chevron7:block/gate_stone"}})
    write_json(os.path.join(ASSETS, "models", "block", "gate_frame.json"), {"textures": {"particle": "chevron7:block/gate_stone"}})
    write_json(os.path.join(ASSETS, "blockstates", "dhd.json"), {"variants": {
        "facing=north": {"model": "chevron7:block/dhd"},
        "facing=east": {"model": "chevron7:block/dhd", "y": 90},
        "facing=south": {"model": "chevron7:block/dhd", "y": 180},
        "facing=west": {"model": "chevron7:block/dhd", "y": 270},
    }})

    side = "#side"
    write_json(os.path.join(ASSETS, "models", "block", "dhd.json"), {
        "parent": "block/block",
        "textures": {"particle": "chevron7:block/dhd_side", "side": "chevron7:block/dhd_side",
                     "top": "chevron7:block/dhd_top", "bottom": "chevron7:block/dhd_bottom"},
        "elements": [
            {"from": [3, 0, 3], "to": [13, 9, 13], "faces": {
                "north": {"uv": [3, 7, 13, 16], "texture": side},
                "south": {"uv": [3, 7, 13, 16], "texture": side},
                "east": {"uv": [3, 7, 13, 16], "texture": side},
                "west": {"uv": [3, 7, 13, 16], "texture": side},
                "up": {"uv": [3, 3, 13, 13], "texture": "#bottom"},
                "down": {"uv": [3, 3, 13, 13], "texture": "#bottom", "cullface": "down"}}},
            {"from": [1, 9, 1], "to": [15, 12, 15],
             "rotation": {"angle": -22.5, "axis": "x", "origin": [8, 10.5, 8]},
             "faces": {
                 "up": {"uv": [0, 0, 16, 16], "texture": "#top"},
                 "down": {"uv": [1, 1, 15, 15], "texture": side},
                 "north": {"uv": [1, 0, 15, 3], "texture": side},
                 "south": {"uv": [1, 0, 15, 3], "texture": side},
                 "east": {"uv": [1, 0, 15, 3], "texture": side},
                 "west": {"uv": [1, 0, 15, 3], "texture": side}}},
        ],
    })
    write_json(os.path.join(ASSETS, "models", "item", "stargate.json"), {"parent": "item/generated", "textures": {"layer0": "chevron7:item/stargate"}})
    write_json(os.path.join(ASSETS, "models", "item", "iris.json"), {"parent": "item/generated", "textures": {"layer0": "chevron7:item/iris"}})
    write_json(os.path.join(ASSETS, "models", "item", "address_book.json"), {"parent": "item/generated", "textures": {"layer0": "chevron7:item/address_book"}})
    write_json(os.path.join(ASSETS, "models", "item", "look_crystal.json"), {"parent": "item/generated", "textures": {"layer0": "chevron7:item/look_crystal"}})
    write_json(os.path.join(ASSETS, "models", "item", "dhd.json"), {"parent": "chevron7:block/dhd"})
    write_json(os.path.join(ASSETS, "lang", "en_us.json"), LANG)

    # loot
    for name in ("stargate", "dhd"):
        write_json(os.path.join(DATA, "loot_tables", "blocks", name + ".json"), {
            "type": "minecraft:block",
            "pools": [{"rolls": 1, "entries": [{"type": "minecraft:item", "name": "chevron7:" + name}],
                       "conditions": [{"condition": "minecraft:survives_explosion"}]}],
        })

    # recipes
    def shaped(name, pattern, key, result, count=1):
        write_json(os.path.join(DATA, "recipes", name + ".json"), {
            "type": "minecraft:crafting_shaped", "category": "misc", "pattern": pattern,
            "key": {k: {"item": v} for k, v in key.items()},
            "result": {"item": result, "count": count},
        })

    shaped("stargate", ["BEB", "ELE", "BEB"],
           {"B": "minecraft:iron_block", "E": "minecraft:ender_eye", "L": "minecraft:lodestone"}, "chevron7:stargate")
    shaped("dhd", [" R ", "GCG", "SSS"],
           {"R": "minecraft:redstone_block", "G": "minecraft:gold_ingot", "C": "minecraft:compass", "S": "minecraft:smooth_sandstone"},
           "chevron7:dhd")
    shaped("iris", ["III", "ITI", "III"], {"I": "minecraft:iron_ingot", "T": "minecraft:iron_trapdoor"}, "chevron7:iris")
    write_json(os.path.join(DATA, "recipes", "look_crystal.json"), {
        "type": "minecraft:crafting_shapeless", "category": "misc",
        "ingredients": [{"item": "minecraft:amethyst_shard"}, {"item": "minecraft:quartz"}, {"item": "minecraft:glowstone_dust"}],
        "result": {"item": "chevron7:look_crystal", "count": 1},
    })
    write_json(os.path.join(DATA, "recipes", "address_book.json"), {
        "type": "minecraft:crafting_shapeless", "category": "misc",
        "ingredients": [{"item": "minecraft:book"}, {"item": "minecraft:ender_eye"}],
        "result": {"item": "chevron7:address_book", "count": 1},
    })

    # tags
    tags = os.path.join(RES, "data", "minecraft", "tags")
    write_json(os.path.join(tags, "blocks", "mineable", "pickaxe.json"),
               {"replace": False, "values": ["chevron7:stargate", "chevron7:gate_frame", "chevron7:dhd"]})
    write_json(os.path.join(tags, "blocks", "needs_iron_tool.json"),
               {"replace": False, "values": ["chevron7:stargate", "chevron7:gate_frame"]})
    write_json(os.path.join(tags, "damage_type", "bypasses_armor.json"), {"replace": False, "values": ["chevron7:kawoosh"]})
    # gate fields: a feature added to plains, meadows and savannas by a Forge biome modifier
    write_json(os.path.join(DATA, "worldgen", "configured_feature", "gate_field.json"),
               {"type": "chevron7:gate_field", "config": {}})
    write_json(os.path.join(DATA, "worldgen", "placed_feature", "gate_field.json"), {
        "feature": "chevron7:gate_field",
        "placement": [
            {"type": "minecraft:rarity_filter", "chance": 600},
            {"type": "minecraft:heightmap", "heightmap": "WORLD_SURFACE_WG"},
            {"type": "minecraft:biome"},
        ],
    })
    write_json(os.path.join(DATA, "tags", "worldgen", "biome", "has_gate_field.json"), {"values": [
        "minecraft:plains", "minecraft:sunflower_plains", "minecraft:meadow", "minecraft:savanna",
    ]})
    write_json(os.path.join(DATA, "forge", "biome_modifier", "gate_field.json"), {
        "type": "forge:add_features",
        "biomes": "#chevron7:has_gate_field",
        "features": "chevron7:gate_field",
        "step": "top_layer_modification",
    })
    # planet gates: one site at chunk 0, 0 of every dimension made of these biomes (Ad Astra's planets).
    # The entries are optional, so the tag loads without Ad Astra.
    write_json(os.path.join(DATA, "worldgen", "configured_feature", "planet_gate.json"),
               {"type": "chevron7:planet_gate", "config": {}})
    write_json(os.path.join(DATA, "worldgen", "placed_feature", "planet_gate.json"), {
        "feature": "chevron7:planet_gate",
        "placement": [
            {"type": "minecraft:heightmap", "heightmap": "WORLD_SURFACE_WG"},
            {"type": "minecraft:biome"},
        ],
    })
    planet_biomes = ["glacio_ice_peaks", "glacio_snowy_barrens", "infernal_venus_barrens", "lunar_wastelands",
                     "martian_canyon_creek", "martian_polar_caps", "martian_wastelands", "mercury_deltas", "venus_wastelands"]
    write_json(os.path.join(DATA, "tags", "worldgen", "biome", "has_planet_gate.json"),
               {"values": [{"id": "ad_astra:" + b, "required": False} for b in planet_biomes]})
    write_json(os.path.join(DATA, "forge", "biome_modifier", "planet_gate.json"), {
        "type": "forge:add_features",
        "biomes": "#chevron7:has_planet_gate",
        "features": "chevron7:planet_gate",
        "step": "surface_structures",
    })
    write_json(os.path.join(DATA, "damage_type", "kawoosh.json"),
               {"exhaustion": 0.0, "message_id": "chevron7.kawoosh", "scaling": "never"})


def main():
    save(gate_stone(), "entity", "gate_stone")
    save(gate_track(), "entity", "gate_track")
    save(chevron(), "entity", "chevron")
    save(event_horizon(), "entity", "event_horizon")
    save(iris(), "entity", "iris")
    save(glyph_atlas(), "gui", "glyphs")
    save(particle(), "block", "gate_stone")
    save(dhd_side(), "block", "dhd_side")
    save(dhd_top(), "block", "dhd_top")
    save(dhd_bottom(), "block", "dhd_bottom")
    save(gate_icon(), "item", "stargate")
    save(iris_icon(), "item", "iris")
    save(address_book_icon(), "item", "address_book")
    save(look_crystal_icon(), "item", "look_crystal")
    for i, (look, spec) in enumerate(LOOKS.items()):
        save(look_stone(spec, i), "entity", "gate_stone_" + look)
        save(look_track(spec, i), "entity", "gate_track_" + look)
        save(look_horizon(spec, i), "entity", "event_horizon_" + look)
    data_files()
    print("resources written to", os.path.normpath(RES))


if __name__ == "__main__":
    main()
