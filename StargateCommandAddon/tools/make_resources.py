"""
Generates the Stargate Command Addon's textures and data files:
blockstates, models, loot tables, recipes, tags and the English names.

    python3 tools/make_resources.py        (run from StargateCommandAddon/)

All textures are drawn here from scratch.
"""
import json
import math
import os

from PIL import Image

MOD = "sgcaddon"
RES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "main", "resources")
ASSETS = os.path.join(RES, "assets", MOD)
DATA = os.path.join(RES, "data", MOD)


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")


def hexc(h, a=255):
    return ((h >> 16) & 255, (h >> 8) & 255, h & 255, a)


def save(img, name):
    path = os.path.join(ASSETS, "textures", "block", name + ".png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)


# --------------------------------------------------------------------------
# textures
# --------------------------------------------------------------------------

def metal_frame(img, x0=0, y0=0):
    """A riveted grey metal border around a 16x16 tile."""
    px = img.load()
    for i in range(16):
        for (x, y) in ((i, 0), (i, 15), (0, i), (15, i)):
            px[x0 + x, y0 + y] = hexc(0x3C4048)
        for (x, y) in ((i, 1), (1, i)):
            if 0 < i < 15:
                px[x0 + x, y0 + y] = hexc(0x8A9099)
        for (x, y) in ((i, 14), (14, i)):
            if 0 < i < 15:
                px[x0 + x, y0 + y] = hexc(0x5A6068)
    for (x, y) in ((2, 2), (13, 2), (2, 13), (13, 13)):
        px[x0 + x, y0 + y] = hexc(0xB8BEC6)


def alarm_light(lit, frame=0, frames=1):
    img = Image.new("RGBA", (16, 16))
    metal_frame(img)
    px = img.load()
    angle = frame / frames * 2 * math.pi
    for y in range(2, 14):
        for x in range(2, 14):
            dx, dy = x - 7.5, y - 7.5
            d = math.hypot(dx, dy)
            if d > 5.6:
                px[x, y] = hexc(0x4A4E56)
                continue
            if not lit:
                c = 0x5A0F0F if d > 3 else 0x7A1616
                if dx < -1 and dy < -1 and d < 4:
                    c = 0x9A3030  # glass highlight
                px[x, y] = hexc(c)
            else:
                # a beam sweeping round, like a rotating beacon
                a = math.atan2(dy, dx)
                diff = abs((a - angle + math.pi) % (2 * math.pi) - math.pi)
                if d < 1.8:
                    c = 0xFFE0C0
                elif diff < 0.55:
                    c = 0xFFF0E0 if diff < 0.25 else 0xFF8A70
                else:
                    c = 0xE02818 if d < 4.2 else 0xB01810
                px[x, y] = hexc(c)
    return img


def gate_monitor(mode):
    img = Image.new("RGBA", (16, 16))
    metal_frame(img)
    px = img.load()
    for y in range(2, 14):
        for x in range(2, 14):
            px[x, y] = hexc(0x14171C)
    # nine chevron lamps in a ring
    lit = {"idle": 0, "open": 9, "incoming": 9}[mode]
    lamp_on = {"idle": 0x6A3A1A, "open": 0xFF8A26, "incoming": 0xFF3A2A}[mode]
    for k in range(9):
        a = math.radians(k * 40 - 90)
        x, y = 7.5 + 4.6 * math.cos(a), 7.5 + 4.6 * math.sin(a)
        px[int(round(x)), int(round(y))] = hexc(lamp_on if k < lit else 0x4A2A16)
    # the event horizon in the middle
    if mode != "idle":
        center = 0x3F8CFF if mode == "open" else 0xFF5A4A
        for y in range(6, 10):
            for x in range(6, 10):
                px[x, y] = hexc(center if (x + y) % 3 else 0xA8D4FF if mode == "open" else 0xFFB0A0)
    return img


def gate_ramp():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()
    for y in range(16):
        for x in range(16):
            frame = x in (0, 15) or y in (0, 15)
            bar = x % 4 == 0 or y % 4 == 0
            if frame:
                px[x, y] = hexc(0x6E747C)
            elif bar:
                px[x, y] = hexc(0x9AA0A8 if (x + y) % 2 else 0x8A9098)
            # holes between the bars stay transparent
    return img


def wall_panel():
    img = Image.new("RGBA", (16, 16))
    px = img.load()
    for y in range(16):
        for x in range(16):
            n = ((x * 7 + y * 13) * 2654435761 >> 7) % 9
            c = 0xB9B3A6 if n > 1 else 0xAFA99C
            if y in (0, 8) or x == 0:
                c = 0x8D877B  # seams
            px[x, y] = hexc(c)
    for (x, y) in ((2, 2), (13, 2), (2, 10), (13, 10), (2, 5), (13, 5), (2, 13), (13, 13)):
        px[x, y] = hexc(0x6E695F)
    return img


def hazard_stripes():
    img = Image.new("RGBA", (16, 16))
    px = img.load()
    for y in range(16):
        for x in range(16):
            px[x, y] = hexc(0xE8B81C if ((x + y) // 4) % 2 == 0 else 0x1C1C1E)
    return img


def floor_tiles():
    img = Image.new("RGBA", (16, 16))
    px = img.load()
    for y in range(16):
        for x in range(16):
            tile = ((x // 8) + (y // 8)) % 2
            c = 0x5A5E64 if tile else 0x50545A
            if x % 8 == 0 or y % 8 == 0:
                c = 0x3A3D42
            elif (x * 5 + y * 3) % 11 == 0:
                c = 0x62666C
            px[x, y] = hexc(c)
    return img


def make_textures():
    save(alarm_light(False), "alarm_light")
    frames = 8
    strip = Image.new("RGBA", (16, 16 * frames))
    for f in range(frames):
        strip.paste(alarm_light(True, f, frames), (0, 16 * f))
    save(strip, "alarm_light_on")
    with open(os.path.join(ASSETS, "textures", "block", "alarm_light_on.png.mcmeta"), "w") as f:
        json.dump({"animation": {"frametime": 2}}, f)
    for mode in ("idle", "open", "incoming"):
        save(gate_monitor(mode), "gate_monitor" if mode == "idle" else "gate_monitor_" + mode)
    save(gate_ramp(), "gate_ramp")
    save(wall_panel(), "sgc_wall_panel")
    save(hazard_stripes(), "sgc_hazard_stripes")
    save(floor_tiles(), "sgc_floor_tiles")
    dc_textures()


# --------------------------------------------------------------------------
# models and blockstates
# --------------------------------------------------------------------------

def model(name, data):
    write_json(os.path.join(ASSETS, "models", "block", name + ".json"), data)


def item(name, parent=None):
    write_json(os.path.join(ASSETS, "models", "item", name + ".json"), {"parent": f"{MOD}:block/{parent or name}"})


def blockstate(name, data):
    write_json(os.path.join(ASSETS, "blockstates", name + ".json"), data)


def cube(name, texture=None, cutout=False):
    data = {"parent": "minecraft:block/cube_all", "textures": {"all": f"{MOD}:block/{texture or name}"}}
    if cutout:
        data["render_type"] = "minecraft:cutout"
    model(name, data)


def simple_block(name, cutout=False):
    cube(name, cutout=cutout)
    blockstate(name, {"variants": {"": {"model": f"{MOD}:block/{name}"}}})
    item(name)


def stairs(name, texture):
    t = f"{MOD}:block/{texture}"
    for suffix, parent in (("", "stairs"), ("_inner", "inner_stairs"), ("_outer", "outer_stairs")):
        model(name + suffix, {"parent": f"minecraft:block/{parent}", "render_type": "minecraft:cutout",
                              "textures": {"bottom": t, "top": t, "side": t}})
    variants = {}
    for facing, y_rot in (("east", 0), ("south", 90), ("west", 180), ("north", 270)):
        for half in ("bottom", "top"):
            for shape in ("straight", "inner_left", "inner_right", "outer_left", "outer_right"):
                m = name + ("" if shape == "straight" else "_inner" if shape.startswith("inner") else "_outer")
                y = y_rot
                if half == "bottom" and shape in ("inner_left", "outer_left"):
                    y -= 90
                if half == "top" and shape in ("inner_right", "outer_right"):
                    y += 90
                v = {"model": f"{MOD}:block/{m}"}
                if half == "top":
                    v["x"] = 180
                y %= 360
                if y:
                    v["y"] = y
                if half == "top" or y:
                    v["uvlock"] = True
                variants[f"facing={facing},half={half},shape={shape}"] = v
    blockstate(name, {"variants": variants})
    item(name)


def slab(name, texture, full):
    t = f"{MOD}:block/{texture}"
    model(name, {"parent": "minecraft:block/slab", "render_type": "minecraft:cutout", "textures": {"bottom": t, "top": t, "side": t}})
    model(name + "_top", {"parent": "minecraft:block/slab_top", "render_type": "minecraft:cutout", "textures": {"bottom": t, "top": t, "side": t}})
    blockstate(name, {"variants": {
        "type=bottom": {"model": f"{MOD}:block/{name}"},
        "type=top": {"model": f"{MOD}:block/{name}_top"},
        "type=double": {"model": f"{MOD}:block/{full}"},
    }})
    item(name)


def make_models():
    # alarm light: off / lit
    cube("alarm_light")
    cube("alarm_light_on")
    blockstate("alarm_light", {"variants": {
        "lit=false": {"model": f"{MOD}:block/alarm_light"},
        "lit=true": {"model": f"{MOD}:block/alarm_light_on"},
    }})
    item("alarm_light")
    # gate monitor: idle / open / incoming
    cube("gate_monitor")
    cube("gate_monitor_open")
    cube("gate_monitor_incoming")
    variants = {}
    for open_ in ("false", "true"):
        for incoming in ("false", "true"):
            m = "gate_monitor_incoming" if incoming == "true" else "gate_monitor_open" if open_ == "true" else "gate_monitor"
            variants[f"incoming={incoming},open={open_}"] = {"model": f"{MOD}:block/{m}"}
    blockstate("gate_monitor", {"variants": variants})
    item("gate_monitor")
    simple_block("gate_ramp", cutout=True)
    stairs("gate_ramp_stairs", "gate_ramp")
    slab("gate_ramp_slab", "gate_ramp", "gate_ramp")
    for name in ("sgc_wall_panel", "sgc_hazard_stripes", "sgc_floor_tiles"):
        simple_block(name)
    dc_models()


# --------------------------------------------------------------------------
# the SGC dialing computer: a stand, a desk and a screen leaning back
# --------------------------------------------------------------------------

DC = "dialing_computer"
DC_MODES = ("none", "idle", "dialing", "open", "incoming", "incoming_open")
# modes whose screen depends on the number of chevrons locked
DC_COUNTED = ("dialing", "open", "incoming", "incoming_open")

# the screen is 14 x 11 model units, 8 texels to the unit, in the top left of a 128 x 128 texture
SCREEN_W, SCREEN_H, SCREEN_TEX = 112, 88, 128

TEAL, TEAL_DIM, TEAL_DARK = 0x2FD1C8, 0x1C8E88, 0x0C3A38
AMBER, AMBER_HOT = 0xFF9A2A, 0xFFD27A
RED, RED_HOT, RED_DIM = 0xFF3B30, 0xFF9A80, 0x7A1A16
GREY_DIM = 0x2E383C

# chevron angles, clockwise from the top, in locking order; the master chevron (top) locks last
CHEVRON_ANGLES = (40, 80, 120, 240, 280, 320, 160, 200, 0)

# a 3 x 5 font (M and N are wider)
FONT = {
    "0": ("111", "101", "101", "101", "111"), "1": ("010", "110", "010", "010", "111"),
    "2": ("111", "001", "111", "100", "111"), "3": ("111", "001", "111", "001", "111"),
    "4": ("101", "101", "111", "001", "001"), "5": ("111", "100", "111", "001", "111"),
    "6": ("111", "100", "111", "101", "111"), "7": ("111", "001", "001", "010", "010"),
    "8": ("111", "101", "111", "101", "111"), "9": ("111", "101", "111", "001", "111"),
    "A": ("010", "101", "111", "101", "101"), "C": ("011", "100", "100", "100", "011"),
    "D": ("110", "101", "101", "101", "110"), "E": ("111", "100", "110", "100", "111"),
    "G": ("011", "100", "101", "101", "011"), "H": ("101", "101", "111", "101", "101"),
    "I": ("111", "010", "010", "010", "111"), "L": ("100", "100", "100", "100", "111"),
    "M": ("10001", "11011", "10101", "10001", "10001"), "N": ("1001", "1101", "1011", "1001", "1001"),
    "O": ("010", "101", "101", "101", "010"), "P": ("110", "101", "110", "100", "100"),
    "R": ("110", "101", "110", "101", "101"), "S": ("011", "100", "010", "001", "110"),
    "T": ("111", "010", "010", "010", "010"), "V": ("101", "101", "101", "101", "010"),
    " ": ("00", "00", "00", "00", "00"),
}

# small symbols for the filled address boxes, one per chevron
BOX_GLYPHS = (
    ("01110", "10001", "00100"), ("10010", "01100", "10010"), ("00100", "01010", "11111"),
    ("11100", "00100", "00111"), ("10101", "01110", "00100"), ("01010", "11111", "01010"),
    ("11011", "00100", "11011"), ("00111", "01100", "11000"), ("10001", "01010", "00100"),
)

# the column of numbers down the left of the screen
DATA_ROWS = ("87342", "8769", "06080", "05684", "2318", "87525", "57884", "08356")


def text_width(text, scale=1):
    return (sum(len(FONT[ch][0]) for ch in text) + len(text) - 1) * scale


def draw_text(px, x, y, text, color, scale=1):
    for ch in text:
        rows = FONT[ch]
        for j, row in enumerate(rows):
            for i, bit in enumerate(row):
                if bit == "1":
                    for sy in range(scale):
                        for sx in range(scale):
                            px[x + i * scale + sx, y + j * scale + sy] = hexc(color)
        x += (len(rows[0]) + 1) * scale


def rect(px, x0, y0, x1, y1, color, fill=False):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if fill or x in (x0, x1) or y in (y0, y1):
                px[x, y] = hexc(color)


def dc_screen(mode, lit, frame=0):
    """One frame of the dialing computer's screen, after the SGC's dialing computer."""
    img = Image.new("RGBA", (SCREEN_TEX, SCREEN_TEX), hexc(0x16191D))
    px = img.load()
    incoming = mode in ("incoming", "incoming_open")
    dim_frame = mode == "incoming" and frame == 1
    if mode == "none":
        line, line_dim = GREY_DIM, 0x1E2629
    elif incoming:
        line, line_dim = (RED_DIM, 0x4A1210) if dim_frame else (RED, 0x9A2A22)
    else:
        line, line_dim = TEAL, TEAL_DIM

    # bezel and the dark glass
    rect(px, 0, 0, SCREEN_W - 1, SCREEN_H - 1, 0x3E434A, fill=True)
    for i in range(SCREEN_W):
        px[i, 0] = hexc(0x5C626A)
    rect(px, 3, 3, SCREEN_W - 4, SCREEN_H - 4, 0x0C0F12)
    rect(px, 4, 4, SCREEN_W - 5, SCREEN_H - 5, 0x03080B, fill=True)
    if mode == "incoming":
        rect(px, 4, 4, SCREEN_W - 5, SCREEN_H - 5, line)  # the screen's edge flashes red

    # left: a column of numbers, and two octagon diagrams under it
    rect(px, 5, 6, 28, 55, line_dim)
    for k, row in enumerate(DATA_ROWS):
        draw_text(px, 26 - text_width(row), 8 + k * 6, row, line_dim if mode != "none" else 0x1E2629)
    for (ox, oy) in ((11, 62), (22, 62)):
        for y in range(oy - 4, oy + 5):
            for x in range(ox - 4, ox + 5):
                d = max(abs(x - ox), abs(y - oy), (abs(x - ox) + abs(y - oy)) * 0.72)
                if 3.4 <= d < 4.4:
                    px[x, y] = hexc(line_dim)
        for (dx, dy) in ((-1, -1), (1, 0), (0, 2)):
            px[ox + dx, oy + dy] = hexc(line)

    # the gate in the middle
    cx, cy, r_out, r_in = 53.0, 36.5, 25.0, 19.0
    total = max(7, lit)
    lit_at = set()
    for i in range(1, lit + 1):
        lit_at.add(CHEVRON_ANGLES[8] if i >= total else CHEVRON_ANGLES[i - 1])
    newest = None
    if mode == "dialing" and lit:
        newest = CHEVRON_ANGLES[8] if lit >= total else CHEVRON_ANGLES[lit - 1]
    hot = RED if incoming else AMBER
    hot_core = RED_HOT if incoming else AMBER_HOT
    if dim_frame:
        hot, hot_core = RED_DIM, RED
    horizon = mode in ("open", "incoming_open")
    for y in range(4, SCREEN_H - 18):
        for x in range(30, 80):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            ang = math.degrees(math.atan2(dx, -dy)) % 360
            c = None
            if horizon and d < r_in - 0.6:
                t = d / r_in
                ripple = 0.5 + 0.5 * math.sin(d * 1.3 - ang * 0.05)
                base = (int(30 + 110 * (1 - t) + 30 * ripple), int(80 + 120 * (1 - t) + 30 * ripple), 255)
                n = (x * 73856093 ^ y * 19349663) % 97
                if n < 4:
                    base = (220, 240, 255)
                px[x, y] = base + (255,)
                continue
            if abs(d - r_out) < 0.6 or abs(d - r_in) < 0.6:
                c = line
            elif r_in < d < r_out:
                # the 39 symbols round the ring, as dim spokes
                f = (ang / (360 / 39)) % 1
                if f < 0.12 and mode != "none":
                    c = line_dim
                elif mode != "none" and 21.2 < d < 22.8 and abs(f - 0.5) < 0.08:
                    c = TEAL_DARK if not incoming else 0x3A0E0C
            # chevrons: wedges pointing in at the ring
            for a in CHEVRON_ANGLES:
                diff = abs((ang - a + 180) % 360 - 180)
                if 23.0 <= d <= 29.5:
                    half = 1.2 + (d - 23.0) * 0.42
                    if math.radians(diff) * d <= half:
                        edge = math.radians(diff) * d > half - 1.0 or d > 28.6 or d < 23.9
                        if a in lit_at and mode != "none":
                            colour = hot if (newest is None or a == newest or incoming) else TEAL
                            c = colour if edge else hot_core if colour != TEAL else 0xA8F4EE
                        else:
                            c = line_dim if edge else 0x061412
            if c is not None:
                px[x, y] = hexc(c)
    # corner brackets round the gate
    for (bx, by, sx, sy) in ((29, 9, 1, 1), (77, 9, -1, 1), (29, 64, 1, -1), (77, 64, -1, -1)):
        for k in range(5):
            px[bx + sx * k, by] = hexc(line_dim)
            px[bx, by + sy * k] = hexc(line_dim)

    # right: the address boxes, numbered
    rows = total
    pitch, top = (8, 8) if rows <= 7 else (7, 6) if rows == 8 else (7, 4)
    for k in range(rows):
        y = top + k * pitch
        number = str(k + 1)
        draw_text(px, 82, y, number, line if mode != "none" else GREY_DIM)
        bx0, bx1 = 87, 105
        if k < lit and mode != "none":
            fill = RED if incoming and not dim_frame else RED_DIM if incoming else (
                AMBER if mode == "dialing" and k == lit - 1 else TEAL)
            rect(px, bx0, y, bx1, y + 4, fill, fill=True)
            glyph = BOX_GLYPHS[k % len(BOX_GLYPHS)]
            for j, row in enumerate(glyph):
                for i, bit in enumerate(row):
                    if bit == "1":
                        px[94 + i, y + 1 + j] = hexc(0x06201E if not incoming else 0x300806)
        else:
            rect(px, bx0, y, bx1, y + 4, line_dim if mode != "none" else 0x1E2629)

    # status line under a rule
    for x in range(6, SCREEN_W - 6):
        px[x, SCREEN_H - 18] = hexc(line_dim)
    if mode == "none":
        status, colour = "NO STARGATE", 0xE0A030
    elif mode == "idle":
        status, colour = "IDLE", line
    elif mode == "dialing":
        status, colour = ("CHEVRON %d" % lit) if lit else "DIALING", AMBER
    elif mode == "open":
        status, colour = "GATE OPEN", line
    else:
        status, colour = "INCOMING", RED_DIM if dim_frame else RED
    draw_text(px, 8, SCREEN_H - 16, status, colour, scale=2)
    return img


def dc_metal(base=0x3A3E44, seed=1):
    img = Image.new("RGBA", (16, 16))
    px = img.load()
    for y in range(16):
        for x in range(16):
            n = ((x * 31 + y * 17 + seed * 7) * 2654435761 >> 9) % 7
            r, g, b = (base >> 16) & 255, (base >> 8) & 255, base & 255
            k = (n - 3) * 2
            px[x, y] = (max(0, r + k), max(0, g + k), max(0, b + k), 255)
    return img


def dc_textures():
    folder = os.path.join(ASSETS, "textures", "block", DC)
    os.makedirs(folder, exist_ok=True)

    def put(img, name):
        img.save(os.path.join(folder, name + ".png"))

    put(dc_metal(), "metal")
    casing = dc_metal(0x4A4F56, 2)
    put(casing, "casing")
    back = casing.copy()
    bpx = back.load()
    for y in range(3, 14, 3):
        for x in range(3, 13):
            bpx[x, y] = hexc(0x16191C)  # vents
    put(back, "casing_back")
    plinth = dc_metal(0x33373C, 3)
    ppx = plinth.load()
    for i in range(16):
        for (x, y) in ((i, 1), (1, i), (i, 14), (14, i)):
            ppx[x, y] = hexc(0x50555C)
    for (x, y) in ((2, 2), (13, 2), (2, 13), (13, 13)):
        ppx[x, y] = hexc(0xC8CED6)  # the white studs on the base's corners
    put(plinth, "plinth")
    column = Image.new("RGBA", (16, 16))
    cpx = column.load()
    for y in range(16):
        for x in range(16):
            ridge = y % 4
            c = (0x4A4F56, 0x3A3E44, 0x2A2D31, 0x1E2124)[ridge]
            cpx[x, y] = hexc(c)
    put(column, "column")
    desk = dc_metal(0x3A3E44, 4)
    dpx = desk.load()
    for x in range(16):
        dpx[x, 6] = hexc(0x2A2D31)
        dpx[x, 7] = hexc(0xB8C0C8)  # the light strip along the desk
        dpx[x, 8] = hexc(0x6A7078)
    put(desk, "desk")
    keyboard = Image.new("RGBA", (16, 16), hexc(0x202326))
    kpx = keyboard.load()
    for y in range(16):
        for x in range(16):
            if y % 2 == 1 and x % 2 == 0:
                kpx[x, y] = hexc(0x5A6068)
    for (x, y) in ((10, 3), (12, 3), (10, 5), (12, 5), (11, 5)):
        kpx[x, y] = hexc(0xE8C030)  # the yellow keys
    kpx[4, 5] = hexc(TEAL)
    put(keyboard, "keyboard")
    cable = Image.new("RGBA", (16, 16))
    lpx = cable.load()
    for y in range(16):
        for x in range(16):
            lpx[x, y] = hexc((0xC89A18, 0xE8C030, 0xF8DA60, 0xE8C030)[x % 4] if y % 5 else 0x9A7410)
    put(cable, "cable")

    for mode in DC_MODES:
        counts = range(10) if mode in DC_COUNTED else (None,)
        for n in counts:
            name = mode if n is None else "%s_%d" % (mode, n)
            if mode == "incoming":
                strip = Image.new("RGBA", (SCREEN_TEX, SCREEN_TEX * 2))
                strip.paste(dc_screen(mode, n, 0), (0, 0))
                strip.paste(dc_screen(mode, n, 1), (0, SCREEN_TEX))
                put(strip, "screen_" + name)
                with open(os.path.join(folder, "screen_" + name + ".png.mcmeta"), "w") as f:
                    json.dump({"animation": {"frametime": 10}}, f)
            else:
                put(dc_screen(mode, n or 0), "screen_" + name)


def dc_models():
    t = lambda name: f"{MOD}:block/{DC}/{name}"

    def faces(tex, uv=None, **extra):
        out = {}
        for side in ("north", "east", "south", "west", "up", "down"):
            out[side] = {"texture": extra.get(side, tex)}
            if uv and side in uv:
                out[side]["uv"] = uv[side]
        return out

    screen_face = {"texture": "#screen", "uv": [0, 0, 14, 11],
                   "forge_data": {"block_light": 15, "sky_light": 15, "ambient_occlusion": False}}
    casing_faces = faces("#casing", south="#casing_back")
    casing_faces["north"] = screen_face
    model(DC, {
        "parent": "minecraft:block/block",
        "textures": {
            "particle": t("casing"), "metal": t("metal"), "casing": t("casing"), "casing_back": t("casing_back"),
            "plinth": t("plinth"), "column": t("column"), "desk": t("desk"), "keyboard": t("keyboard"),
            "cable": t("cable"), "screen": t("screen_idle"),
        },
        "display": {
            "gui": {"rotation": [30, 225, 0], "translation": [0, -2.5, 0], "scale": [0.5, 0.5, 0.5]},
            "fixed": {"rotation": [0, 0, 0], "translation": [0, -2, 0], "scale": [0.45, 0.45, 0.45]},
            "ground": {"rotation": [0, 0, 0], "translation": [0, 2, 0], "scale": [0.25, 0.25, 0.25]},
        },
        "elements": [
            {"name": "base plate", "from": [1, 0, 1], "to": [15, 1, 15], "faces": faces("#metal", up="#plinth")},
            {"name": "base step", "from": [2, 1, 2], "to": [14, 2, 14], "faces": faces("#metal")},
            {"name": "column", "from": [4, 2, 4], "to": [12, 10, 12],
             "faces": faces("#column", uv={s: [4, 6, 12, 14] for s in ("north", "east", "south", "west")},
                            up="#metal", down="#metal")},
            {"name": "cable", "from": [5, 2, 3.4], "to": [6, 10, 4], "faces": faces("#cable")},
            {"name": "desk", "from": [1, 10, 2], "to": [15, 13, 14],
             "faces": faces("#desk", uv={s: [1, 5, 15, 8] for s in ("north", "south")} |
                            {s: [2, 5, 14, 8] for s in ("east", "west")}, up="#metal", down="#metal")},
            {"name": "keyboard", "from": [2, 13, 2.5], "to": [14, 13.75, 6.5],
             "faces": faces("#metal", uv={"up": [2, 2, 14, 6]}, up="#keyboard")},
            {"name": "screen", "from": [1, 13, 7], "to": [15, 24, 10],
             "rotation": {"origin": [8, 13, 7], "axis": "x", "angle": 22.5},
             "faces": casing_faces},
        ],
    })
    variants = {}
    for facing, y_rot in (("north", 0), ("east", 90), ("south", 180), ("west", 270)):
        for mode in DC_MODES:
            counts = range(10) if mode in DC_COUNTED else (None,)
            for n in counts:
                name = mode if n is None else "%s_%d" % (mode, n)
                key = f"facing={facing},mode={mode}" + ("" if n is None else f",chevrons={n}")
                v = {"model": f"{MOD}:block/{DC}_{name}"}
                if y_rot:
                    v["y"] = y_rot
                variants[key] = v
    for mode in DC_MODES:
        counts = range(10) if mode in DC_COUNTED else (None,)
        for n in counts:
            name = mode if n is None else "%s_%d" % (mode, n)
            model(f"{DC}_{name}", {"parent": f"{MOD}:block/{DC}", "textures": {"screen": t("screen_" + name)}})
    blockstate(DC, {"variants": variants})
    item(DC, f"{DC}_idle")


# --------------------------------------------------------------------------
# data: loot tables, recipes, tags
# --------------------------------------------------------------------------

BLOCKS = ["alarm_light", "gate_monitor", "dialing_computer", "gate_ramp", "gate_ramp_stairs", "gate_ramp_slab",
          "sgc_wall_panel", "sgc_hazard_stripes", "sgc_floor_tiles"]


def loot(name, slab_=False):
    entry = {"type": "minecraft:item", "name": f"{MOD}:{name}"}
    if slab_:
        entry["functions"] = [{
            "function": "minecraft:set_count", "count": 2, "add": False,
            "conditions": [{"condition": "minecraft:block_state_property", "block": f"{MOD}:{name}",
                            "properties": {"type": "double"}}],
        }, {"function": "minecraft:explosion_decay"}]
    write_json(os.path.join(DATA, "loot_tables", "blocks", name + ".json"), {
        "type": "minecraft:block",
        "pools": [{"rolls": 1, "entries": [entry], "conditions": [{"condition": "minecraft:survives_explosion"}]}],
    })


def shaped(name, pattern, key, count=1):
    write_json(os.path.join(DATA, "recipes", name + ".json"), {
        "type": "minecraft:crafting_shaped",
        "category": "building",
        "pattern": pattern,
        "key": {k: {"item": v} for k, v in key.items()},
        "result": {"item": f"{MOD}:{name}", "count": count},
    })


def make_data():
    for name in BLOCKS:
        loot(name, slab_=name.endswith("_slab"))
    shaped("alarm_light", [" D ", "GLG", " I "], {"D": "minecraft:red_dye", "G": "minecraft:glass_pane",
                                                   "L": "minecraft:redstone_lamp", "I": "minecraft:iron_ingot"})
    shaped("gate_monitor", ["IRI", "ICI", "III"], {"I": "minecraft:iron_ingot", "R": "minecraft:redstone",
                                                   "C": "minecraft:comparator"})
    shaped("dialing_computer", ["PPP", "IMI", " I "], {"P": "minecraft:glass_pane", "I": "minecraft:iron_ingot",
                                                        "M": f"{MOD}:gate_monitor"})
    shaped("gate_ramp", ["BB", "BB"], {"B": "minecraft:iron_bars"}, 4)
    shaped("gate_ramp_stairs", ["R  ", "RR ", "RRR"], {"R": f"{MOD}:gate_ramp"}, 4)
    shaped("gate_ramp_slab", ["RRR"], {"R": f"{MOD}:gate_ramp"}, 6)
    shaped("sgc_wall_panel", ["SS", "SS"], {"S": "minecraft:smooth_stone"}, 4)
    shaped("sgc_hazard_stripes", ["YB", "BY"], {"Y": "minecraft:yellow_concrete", "B": "minecraft:black_concrete"}, 4)
    shaped("sgc_floor_tiles", ["GL", "LG"], {"G": "minecraft:gray_concrete", "L": "minecraft:light_gray_concrete"}, 4)
    write_json(os.path.join(RES, "data", "minecraft", "tags", "blocks", "mineable", "pickaxe.json"),
               {"replace": False, "values": [f"{MOD}:{b}" for b in BLOCKS]})
    write_json(os.path.join(RES, "data", "minecraft", "tags", "blocks", "stairs.json"),
               {"replace": False, "values": [f"{MOD}:gate_ramp_stairs"]})
    write_json(os.path.join(RES, "data", "minecraft", "tags", "blocks", "slabs.json"),
               {"replace": False, "values": [f"{MOD}:gate_ramp_slab"]})


def make_lang():
    write_json(os.path.join(ASSETS, "lang", "en_us.json"), {
        "itemGroup.sgcaddon": "Stargate Command",
        "block.sgcaddon.alarm_light": "Gate Room Alarm Light",
        "block.sgcaddon.gate_monitor": "Gate Monitor",
        "block.sgcaddon.dialing_computer": "SGC Dialing Computer",
        "block.sgcaddon.dialing_computer.none": "No stargate within %2$s blocks",
        "block.sgcaddon.dialing_computer.idle": "Stargate idle",
        "block.sgcaddon.dialing_computer.dialing.start": "Dialing",
        "block.sgcaddon.dialing_computer.dialing": "Chevron %1$s encoded",
        "block.sgcaddon.dialing_computer.dialing.locked": "Chevron %1$s locked",
        "block.sgcaddon.dialing_computer.open": "Wormhole established: %1$s chevrons locked",
        "block.sgcaddon.dialing_computer.incoming": "Unscheduled offworld activation!",
        "block.sgcaddon.dialing_computer.incoming_open": "Incoming wormhole open",
        "block.sgcaddon.gate_ramp": "Gate Ramp Grating",
        "block.sgcaddon.gate_ramp_stairs": "Gate Ramp Stairs",
        "block.sgcaddon.gate_ramp_slab": "Gate Ramp Slab",
        "block.sgcaddon.sgc_wall_panel": "SGC Wall Panel",
        "block.sgcaddon.sgc_hazard_stripes": "SGC Hazard Stripes",
        "block.sgcaddon.sgc_floor_tiles": "SGC Floor Tiles",
    })


if __name__ == "__main__":
    make_textures()
    make_models()
    make_data()
    make_lang()
    print("resources written to", os.path.normpath(RES))
