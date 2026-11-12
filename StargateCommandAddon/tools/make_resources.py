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


# --------------------------------------------------------------------------
# data: loot tables, recipes, tags
# --------------------------------------------------------------------------

BLOCKS = ["alarm_light", "gate_monitor", "gate_ramp", "gate_ramp_stairs", "gate_ramp_slab",
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
