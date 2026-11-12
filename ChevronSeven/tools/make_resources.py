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
    img = noise_tile(32, 32, (150, 154, 160), 30, 21, grain=2)
    d = ImageDraw.Draw(img)
    for x in range(0, 32, 4):
        d.line([(x, 0), (x + 6, 31)], fill=(170, 174, 180, 255))
    d.line([(0, 0), (0, 31)], fill=(70, 72, 78, 255), width=2)
    d.line([(31, 0), (31, 31)], fill=(196, 200, 206, 255))
    return img


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
    "death.attack.chevron7.kawoosh": "%1$s was vaporised by a kawoosh",
    "death.attack.chevron7.kawoosh.player": "%1$s was vaporised by a kawoosh while fighting %2$s",
    "message.chevron7.no_room": "Not enough room: a stargate needs a clear 7 by 7 space",
    "message.chevron7.address": "This gate's address: %s",
    "message.chevron7.iris_installed": "Iris fitted",
    "message.chevron7.iris_already": "This gate already has an iris",
    "message.chevron7.no_iris": "That gate has no iris",
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

    # tags
    tags = os.path.join(RES, "data", "minecraft", "tags")
    write_json(os.path.join(tags, "blocks", "mineable", "pickaxe.json"),
               {"replace": False, "values": ["chevron7:stargate", "chevron7:gate_frame", "chevron7:dhd"]})
    write_json(os.path.join(tags, "blocks", "needs_iron_tool.json"),
               {"replace": False, "values": ["chevron7:stargate", "chevron7:gate_frame"]})
    write_json(os.path.join(tags, "damage_type", "bypasses_armor.json"), {"replace": False, "values": ["chevron7:kawoosh"]})
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
    data_files()
    print("resources written to", os.path.normpath(RES))


if __name__ == "__main__":
    main()
