"""
Builds the Stargate Journey gate variants of this pack.

The textures are recoloured from Stargate Journey's own Milky Way gate
textures (CC BY-NC-SA 4.0, Povstalec and contributors), so they fit its gate
model exactly. Run from anywhere:

    python3 make_variants.py <stargate journey checkout or textures dir> <output dir> [zip file]

<output dir> gets assets/ and data/ trees that work as a resource pack, a data
pack, or inside a mod jar.
"""
import json
import os
import random
import sys
import zipfile

from PIL import Image

NS = "sgcvariants"  # namespace of this pack

# --------------------------------------------------------------------------
# colour helpers
# --------------------------------------------------------------------------


def hexc(h):
    return ((h >> 16) & 255, (h >> 8) & 255, h & 255)


def ramp(colors, t):
    """Colour at t (0..1) along a list of colours."""
    t = max(0.0, min(1.0, t))
    pos = t * (len(colors) - 1)
    i = min(int(pos), len(colors) - 2)
    f = pos - i
    a, b = hexc(colors[i]), hexc(colors[i + 1])
    return tuple(int(a[k] + (b[k] - a[k]) * f + 0.5) for k in range(3))


def lum(r, g, b):
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255


def is_light(r, g, b):
    """Chevron lights: red, orange and yellow pixels (warm and saturated)."""
    return r > 70 and b < r * 0.62 and r - b > 60


# --------------------------------------------------------------------------
# the variants
# --------------------------------------------------------------------------

VARIANTS = {
    # Stargate Origins (1939): weathered, dusty stone, amber lamp-lit chevrons, faded film-toned horizon
    "origins": {
        "name": "Origins",
        "stone": [0x2B241D, 0x5E5243, 0x8F826F, 0xC2B396],
        "specks": ("dark", 0.13),
        "light_off": [0x2E1E10, 0x5A3C20],
        "light_on": [0x7A3E0C, 0xE8963A, 0xFFE2A8],
        "horizon": [0x0F2236, 0x2E5576, 0x86A6BD, 0xEDE4D2],
        "vortex": [0x1A2A38, 0x5A7A90, 0xE6DCC8],
        "symbols": (72, 60, 46),
        "recipe": ("minecraft:chiseled_sandstone", "sgjourney:naquadah"),
    },
    # Stargate: Continuum: the gate found frozen in the Arctic, frosted and flecked with ice
    "continuum": {
        "name": "Continuum",
        "stone": [0x26323C, 0x627585, 0x9FAFBF, 0xD6E3EE],
        "specks": ("frost", 0.16),
        "light_off": [0x34221C, 0x62362A],
        "light_on": [0x8A2A00, 0xFF7A33, 0xFFE0B8],
        "horizon": [0x08285E, 0x2C86D9, 0x9FDCFF, 0xF4FBFF],
        "vortex": [0x0A2C66, 0x5FB8F0, 0xF4FBFF],
        "symbols": (54, 66, 80),
        "recipe": ("minecraft:blue_ice", "sgjourney:naquadah"),
    },
    # Stargate: The Ark of Truth: an Ancient gate in aged gold, a wormhole of golden light
    "ark_of_truth": {
        "name": "Ark of Truth",
        "stone": [0x33240C, 0x7D6031, 0xB89650, 0xEED48A],
        "specks": None,
        "light_off": [0x42290C, 0x74501E],
        "light_on": [0xA86E0C, 0xFFC94D, 0xFFF8E0],
        "horizon": [0x52300A, 0xD08A1E, 0xFFD36B, 0xFFF8E6],
        "vortex": [0x5A3408, 0xFFC94D, 0xFFFBEE],
        "symbols": (70, 48, 14),
        "recipe": ("minecraft:gold_block", "sgjourney:naquadah"),
    },
    # Stargate Infinity, the animated series: a pale cartoon gate with ink outlines,
    # lime-yellow chevrons and a pale whirlpool with dark lines
    "infinity": {
        "name": "Infinity",
        "stone": [0x14161C, 0x8995AA, 0xB4C0D2, 0xE6ECF4],
        "posterize": 4,
        "specks": None,
        "light_off": [0x14161C, 0x2E3440],
        "light_on": [0x6E8A10, 0xD6F23C, 0xF7FFB0],
        "horizon": [0xF4F8FC, 0xD9E9F7, 0xA9C8E8, 0x1A1E26],
        "vortex": [0xC9DDF2, 0xF4F8FC, 0xFFFFFF],
        "symbols": (20, 22, 28),
        "recipe": ("minecraft:lime_dye", "minecraft:book"),
    },
}

# variant name -> the Gate Room / Personal Dialer look it switches on
GATE_ROOM_LOOK = {"origins": "Origins", "continuum": "Continuum", "ark_of_truth": "Ark of Truth", "infinity": "Infinity"}


def recolor_gate(src, v, engaged=False, seed=1):
    im = src.convert("RGBA")
    px = im.load()
    w, h = im.size
    lums = [lum(*px[x, y][:3]) for y in range(h) for x in range(w) if px[x, y][3] > 0 and not is_light(*px[x, y][:3])]
    lo, hi = (min(lums), max(lums)) if lums else (0, 1)
    rnd = random.Random(seed)
    out = Image.new("RGBA", (w, h))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                op[x, y] = (0, 0, 0, 0)
                continue
            l = lum(r, g, b)
            if is_light(r, g, b):
                c = ramp(v["light_on"] if engaged else v["light_off"], l * 1.2)
            else:
                t = (l - lo) / (hi - lo) if hi > lo else l
                if v.get("posterize"):
                    n = v["posterize"]
                    t = round(t * (n - 1)) / (n - 1)
                c = ramp(v["stone"], t)
                specks = v.get("specks")
                if specks and not engaged and rnd.random() < specks[1]:
                    if specks[0] == "dark":
                        c = tuple(int(k * 0.62) for k in c)
                    else:
                        c = tuple(int(k + (245 - k) * 0.8) for k in c)
            op[x, y] = c + (a,)
    return out


def recolor_strip(src, colors):
    """Animated textures (event horizon, kawoosh): map brightness onto the variant's colours."""
    im = src.convert("RGBA")
    px = im.load()
    w, h = im.size
    out = Image.new("RGBA", (w, h))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                op[x, y] = (0, 0, 0, 0)
                continue
            # the blue horizon is mostly dark: stretch its brightness
            t = min(1.0, lum(r, g, b) * 1.6)
            op[x, y] = ramp(colors, t) + (a,)
    return out


def animation(texture, rows, columns, frames, alpha):
    return {
        "texture": texture, "rows": rows, "columns": columns, "frames": frames,
        "rgba": {"red": 1.0, "blue": 1.0, "green": 1.0, "alpha": alpha},
    }


def client_variant(name):
    t = f"{NS}:textures/entity/stargate/milky_way/{name}/{name}"
    horizon = f"{t}_event_horizon.png"
    vortex = f"{t}_vortex.png"
    wormhole = {
        "event_horizon": {"front": animation(horizon, 32, 1, 32, 1.0), "back": animation(horizon, 32, 1, 32, 0.75)},
        "event_horizon_unstable": {"front": animation(horizon, 32, 1, 32, 0.75), "back": animation(horizon, 32, 1, 32, 0.75)},
        "strudel": {"front": animation(vortex, 32, 5, 160, 1.0), "back": animation(vortex, 32, 5, 160, 1.0)},
        "disconnect_ticks": {"wait_ticks": 16, "fade_in_ticks": 10, "stable_ticks": 0, "fade_out_ticks": 20},
        "disconnect": {
            "front": animation("sgjourney:textures/entity/stargate/milky_way/milky_way_disconnect.png", 20, 1, 20, 1.0),
            "back": animation("sgjourney:textures/entity/stargate/milky_way/milky_way_disconnect.png", 20, 1, 20, 1.0),
        },
    }
    r, g, b = VARIANTS[name]["symbols"]
    return {
        "texture": f"{t}_stargate.png",
        "engaged_texture": f"{t}_stargate_engaged.png",
        "wormhole": wormhole,
        "shiny_wormhole": wormhole,
        "symbols": {"idle_symbols": {"color": {"r": r, "g": g, "b": b}}},
        "stargate_model": {"raise_back_chevrons": False},
        "chevron_engaged_sounds": {"default": "sgjourney:milky_way_chevron_engage"},
        "chevron_incoming_sounds": {"default": "sgjourney:milky_way_chevron_engage"},
        "chevron_open_sounds": {"default": "sgjourney:milky_way_chevron_open"},
        "chevron_encode_sounds": {"default": "sgjourney:milky_way_chevron_encode"},
        "rotation_sounds": {
            "rotation_startup_sound": "sgjourney:milky_way_ring_spin_start",
            "rotation_sound": "sgjourney:milky_way_ring_spin",
            "rotation_stop_sound": "sgjourney:milky_way_ring_spin_stop",
        },
        "wormhole_sounds": {
            "open": "sgjourney:milky_way_wormhole_open",
            "idle": "sgjourney:milky_way_wormhole_idle",
            "close": "sgjourney:milky_way_wormhole_close",
        },
        "fail_sounds": {"default": "sgjourney:milky_way_dial_fail"},
    }


def find(root, filename):
    for dirpath, _, files in os.walk(root):
        if filename in files:
            return os.path.join(dirpath, filename)
    raise SystemExit(f"{filename} not found under {root}")


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent="\t")
        f.write("\n")


def main():
    src_root, out = sys.argv[1], sys.argv[2]
    gate = Image.open(find(src_root, "milky_way_stargate.png"))
    engaged = Image.open(find(src_root, "milky_way_stargate_engaged.png"))
    horizon = Image.open(find(src_root, "milky_way_event_horizon.png"))
    vortex = Image.open(find(src_root, "milky_way_vortex.png"))
    lang = {}
    for i, (name, v) in enumerate(VARIANTS.items()):
        tex = os.path.join(out, "assets", NS, "textures", "entity", "stargate", "milky_way", name)
        os.makedirs(tex, exist_ok=True)
        recolor_gate(gate, v, False, seed=i + 1).save(os.path.join(tex, f"{name}_stargate.png"), optimize=True)
        recolor_gate(engaged, v, True, seed=i + 1).save(os.path.join(tex, f"{name}_stargate_engaged.png"), optimize=True)
        recolor_strip(horizon, v["horizon"]).save(os.path.join(tex, f"{name}_event_horizon.png"), optimize=True)
        recolor_strip(vortex, v["vortex"]).save(os.path.join(tex, f"{name}_vortex.png"), optimize=True)
        write_json(os.path.join(out, "assets", NS, "sgjourney", "stargate_variant", "milky_way", f"{name}.json"), client_variant(name))
        write_json(os.path.join(out, "data", NS, "sgjourney", "stargate_variant", f"milky_way_{name}.json"),
                   {"base_stargate": "sgjourney:milky_way_stargate", "client_variant": f"{NS}:{name}"})
        lang[f"sgjourney.stargate_variant.{NS}.milky_way_{name}"] = v["name"]
        # a blank variant crystal + two ingredients in Stargate Journey's crystallizer
        primary, secondary = v["recipe"]
        write_json(os.path.join(out, "data", NS, "recipes", "crystallizing", f"milky_way_{name}_variant_crystal.json"), {
            "type": "sgjourney:crystallizing",
            "crystal_base": {"item": "sgjourney:stargate_variant_crystal", "amount": 1},
            "primary_ingredient": {"item": primary, "amount": 1},
            "secondary_ingredient": {"item": secondary, "amount": 1},
            "deplete_primary": True,
            "deplete_secondary": True,
            "output": {"item": "sgjourney:stargate_variant_crystal", "nbt": {"Variant": f"{NS}:milky_way_{name}"}},
            "progress": 100,
            "input_fluid": {"id": "sgjourney:liquid_naquadah", "amount": 100},
        })
    write_json(os.path.join(out, "assets", NS, "lang", "en_us.json"), lang)
    # one pack.mcmeta for both: Minecraft 1.20.1 uses pack format 15 for resource and data packs
    write_json(os.path.join(out, "pack.mcmeta"), {"pack": {
        "pack_format": 15,
        "description": "Stargate Journey gate variants: Origins, Continuum, Ark of Truth, Infinity",
    }})
    print("built", ", ".join(VARIANTS))
    if len(sys.argv) > 3:
        with zipfile.ZipFile(sys.argv[3], "w", zipfile.ZIP_DEFLATED) as z:
            for dirpath, _, files in os.walk(out):
                for f in sorted(files):
                    full = os.path.join(dirpath, f)
                    z.write(full, os.path.relpath(full, out))
        print("zipped", sys.argv[3])


if __name__ == "__main__":
    main()
