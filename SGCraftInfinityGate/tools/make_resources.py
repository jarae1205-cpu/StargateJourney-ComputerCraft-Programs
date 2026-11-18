"""
Writes the resources of Infinity Stargate for SGCraft: the base block's textures, its block
states and models, the recipe, the English names and mcmod.info.

    python3 tools/make_resources.py        (run from SGCraftInfinityGate/; needs Pillow)

The textures are drawn here from scratch. The gate itself has no textures of its own: the mod
recolours SGCraft's as the game loads them (see client/InfinityTextures.java).
"""
import json
import os
import random

from PIL import Image, ImageDraw

MOD = "sginfinity"
RES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "main", "resources")
ASSETS = os.path.join(RES, "assets", MOD)

# the cartoon's colours: pale stone, black ink outlines, lime-yellow chevrons
PALE = (214, 220, 230)
SHADE = (176, 184, 198)
INK = (34, 38, 52)
LIME = (200, 230, 60)
LIME_DARK = (132, 160, 30)


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(text)


def write_json(path, data):
    write(path, json.dumps(data, indent=2) + "\n")


def stone(seed):
    """Flat pale stone, a little mottled, with an ink outline: a cel-shaded block."""
    rnd = random.Random(seed)
    img = Image.new("RGBA", (16, 16), PALE + (255,))
    px = img.load()
    for y in range(16):
        for x in range(16):
            if rnd.random() < 0.18:
                px[x, y] = SHADE + (255,)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 15, 15], outline=INK + (255,))
    d.line([(1, 14), (14, 14)], fill=SHADE + (255,))
    d.line([(14, 1), (14, 14)], fill=SHADE + (255,))
    return img


def base_front():
    """The front of the base: a lime chevron over a dark display slit, all in ink outlines."""
    img = stone(2)
    d = ImageDraw.Draw(img)
    d.polygon([(3, 3), (12, 3), (7.5, 9)], fill=LIME + (255,), outline=INK + (255,))
    d.polygon([(6, 3), (9, 3), (7.5, 5)], fill=PALE + (255,), outline=INK + (255,))
    d.line([(4, 4), (6, 4)], fill=(236, 250, 150, 255))
    d.rectangle([3, 11, 12, 13], fill=INK + (255,))
    for x in (5, 8, 11):
        d.point((x, 12), fill=LIME_DARK + (255,))
    return img


def main():
    tex = os.path.join(ASSETS, "textures", "blocks")
    os.makedirs(tex, exist_ok=True)
    stone(1).save(os.path.join(tex, "infinity_base_side.png"))
    base_front().save(os.path.join(tex, "infinity_base_front.png"))

    # The base faces the way its placer looked (SGCraft's own rule), and its gate opens towards
    # them: the model's front, north in "orientable", is turned to face back at the placer.
    turn = {"north": 180, "south": 0, "east": 270, "west": 90}
    variants = {}
    for facing in ("west", "east", "south", "north"):
        for merged in ("false", "true"):
            v = {"model": MOD + (":infinity_base_merged" if merged == "true" else ":infinity_base")}
            if merged == "false" and turn[facing]:
                v["y"] = turn[facing]
            variants["facing=%s,merged=%s" % (facing, merged)] = v
    write_json(os.path.join(ASSETS, "blockstates", "infinity_base.json"), {"variants": variants})
    write_json(os.path.join(ASSETS, "models", "block", "infinity_base.json"), {
        "parent": "block/orientable",
        "textures": {"front": MOD + ":blocks/infinity_base_front", "side": MOD + ":blocks/infinity_base_side",
                     "top": MOD + ":blocks/infinity_base_side"}})
    # merged into a gate: SGCraft's renderer draws the ring there, so the block draws nothing
    write_json(os.path.join(ASSETS, "models", "block", "infinity_base_merged.json"),
               {"textures": {"particle": MOD + ":blocks/infinity_base_side"}, "elements": []})
    write_json(os.path.join(ASSETS, "models", "item", "infinity_base.json"), {"parent": MOD + ":block/infinity_base"})

    # SGCraft's base and lime dye make an Infinity base
    write_json(os.path.join(ASSETS, "recipes", "infinity_base.json"), {
        "type": "minecraft:crafting_shapeless",
        "ingredients": [{"item": "sgcraft:stargatebase"}, {"item": "minecraft:dye", "data": 10}],
        "result": {"item": MOD + ":infinity_base"}})

    write(os.path.join(ASSETS, "lang", "en_us.lang"), "tile.sginfinity.infinity_base.name=Infinity Stargate Base\n")
    write_json(os.path.join(RES, "mcmod.info"), [{
        "modid": MOD,
        "name": "Infinity Stargate for SGCraft",
        "description": "The gate from the animated series Stargate Infinity, for SGCraft 2.3: an Infinity Stargate Base, "
                       "built into a ring of SGCraft's own Ring and Chevron Blocks.",
        "version": "${version}",
        "mcversion": "${mcversion}",
        "authorList": ["Stargate Command (ComputerCraft programs)"],
        "dependencies": ["sgcraft"],
    }])
    write_json(os.path.join(RES, "pack.mcmeta"), {"pack": {"description": "Infinity Stargate for SGCraft", "pack_format": 3}})
    print("resources written to", os.path.normpath(RES))


if __name__ == "__main__":
    main()
