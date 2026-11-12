--
-- sgc.styles - how each gate looks
--
-- A style recolours the 16 palette slots of the screen it is drawn on, so a
-- monitor can show a stone grey Milky Way ring, a slate Pegasus ring or a dark
-- Universe ring. Every style keeps the same meaning for each slot:
--
--   black      background             white      bright text, brightest horizon
--   lightGray  ring stone, dim text   gray       ring shadow, lines
--   brown      symbol track           pink       symbols (glyphs)
--   magenta    chevron off            orange     chevron lit, accent colour
--   yellow     chevron glow, flash    red        alarm
--   lime       ok                     green      iris (light)
--   purple     iris (dark)            blue/cyan/lightBlue  event horizon, deep to light
--

local S = {}

-- CC: Tweaked default palette
S.DEFAULT = {
    [colors.white] = 0xF0F0F0, [colors.orange] = 0xF2B233, [colors.magenta] = 0xE57FD8, [colors.lightBlue] = 0x99B2F2,
    [colors.yellow] = 0xDEDE6C, [colors.lime] = 0x7FCC19, [colors.pink] = 0xF2B2CC, [colors.gray] = 0x4C4C4C,
    [colors.lightGray] = 0x999999, [colors.cyan] = 0x4C99B2, [colors.purple] = 0xB266E5, [colors.blue] = 0x3366CC,
    [colors.brown] = 0x7F664C, [colors.green] = 0x57A64E, [colors.red] = 0xCC4C4C, [colors.black] = 0x111111,
}

local BASE = {
    [colors.black] = 0x07090D, [colors.white] = 0xF2F6FF, [colors.red] = 0xE0301E, [colors.lime] = 0x6FD34A,
    [colors.green] = 0xA9AEB6, [colors.purple] = 0x5C6068,
    [colors.blue] = 0x0B3C9E, [colors.cyan] = 0x1E73E8, [colors.lightBlue] = 0x7DB8FF,
    [colors.lightGray] = 0x8C9099, [colors.gray] = 0x44484F, [colors.brown] = 0x666A72, [colors.pink] = 0xB7BCC5,
    [colors.magenta] = 0x5E3420, [colors.orange] = 0xFF6A1F, [colors.yellow] = 0xFFC05A,
}

local function palette(over)
    local p = {}
    for k, v in pairs(BASE) do p[k] = v end
    for k, v in pairs(over or {}) do p[k] = v end
    return p
end

-- ring = radii as a fraction of the outer radius:
--   track  outer edge of the symbol track (inner ring)
--   rim    inner edge of the stone
--   horizon  edge of the event horizon
S.LIST = {
    {
        id = "milky_way", room = "GATE ROOM", name = "Milky Way", series = "Stargate Journey",
        shape = "v", track = true,
        palette = palette({ [colors.orange] = 0xFF8A26, [colors.yellow] = 0xFFD27A }),
    },
    {
        id = "sg1", room = "STARGATE COMMAND", name = "SG-1", series = "Stargate SG-1", place = "Stargate Command",
        shape = "v", track = true,
        palette = palette({ [colors.orange] = 0xFF4E1A, [colors.yellow] = 0xFFB050, [colors.magenta] = 0x5A2A1A }),
    },
    {
        id = "movie", room = "STARGATE COMMAND", name = "Movie", series = "Stargate (1994)", place = "Giza, Earth",
        shape = "v", track = true, chevronWidth = 1.3,
        palette = palette({
            [colors.lightGray] = 0xA69A86, [colors.gray] = 0x5E554A, [colors.brown] = 0x7C7266, [colors.pink] = 0xCDC3B2,
            [colors.magenta] = 0x6A4A2A, [colors.orange] = 0xFFA235, [colors.yellow] = 0xFFE08A,
            [colors.blue] = 0x0D4B9A, [colors.cyan] = 0x2A8BE0, [colors.lightBlue] = 0x9CCBFF,
        }),
    },
    {
        id = "pegasus", room = "GATE ROOM", name = "Pegasus", series = "Stargate Journey",
        shape = "v", track = true, glyphLight = true,
        palette = palette({
            [colors.lightGray] = 0x56637A, [colors.gray] = 0x2A3342, [colors.brown] = 0x394557, [colors.pink] = 0x5C86B0,
            [colors.magenta] = 0x203A57, [colors.orange] = 0x38C8FF, [colors.yellow] = 0xCFF4FF,
            [colors.blue] = 0x0A2F86, [colors.cyan] = 0x1666E0, [colors.lightBlue] = 0x6FB0FF,
            [colors.green] = 0x8E9AAE, [colors.purple] = 0x46526A,
        }),
    },
    {
        id = "atlantis", room = "ATLANTIS GATE ROOM", name = "Atlantis", series = "Stargate Atlantis", place = "Lantea, Pegasus",
        shape = "v", track = true, glyphLight = true,
        palette = palette({
            [colors.lightGray] = 0x4F6276, [colors.gray] = 0x243140, [colors.brown] = 0x334457, [colors.pink] = 0x4E9CC0,
            [colors.magenta] = 0x1A3D52, [colors.orange] = 0x2FE3FF, [colors.yellow] = 0xD8FBFF,
            [colors.blue] = 0x08308E, [colors.cyan] = 0x146CE8, [colors.lightBlue] = 0x68BCFF,
            [colors.green] = 0x8A9DB2, [colors.purple] = 0x40546C,
        }),
    },
    {
        id = "universe", room = "DESTINY GATE ROOM", name = "Universe", series = "Stargate Universe", place = "Destiny",
        shape = "light", track = false, glyphLight = true, ring = { track = 0.74, rim = 0.74, horizon = 0.70 },
        palette = palette({
            [colors.lightGray] = 0x585B62, [colors.gray] = 0x2B2D32, [colors.brown] = 0x44474D, [colors.pink] = 0x8C9199,
            [colors.magenta] = 0x34363B, [colors.orange] = 0xF4F7FF, [colors.yellow] = 0xFFFFFF,
            [colors.blue] = 0x102A6A, [colors.cyan] = 0x2A5FC8, [colors.lightBlue] = 0x86AEF0,
        }),
    },
    {
        id = "tollan", room = "TOLLAN GATE", name = "Tollan", series = "Stargate SG-1", place = "Tollana",
        shape = "slim", track = false, ring = { track = 0.88, rim = 0.88, horizon = 0.84 },
        palette = palette({
            [colors.lightGray] = 0xD5DAE1, [colors.gray] = 0x8E959E, [colors.brown] = 0xC0C6CE, [colors.pink] = 0xE6EAF0,
            [colors.magenta] = 0x7D8C9C, [colors.orange] = 0x8FD6FF, [colors.yellow] = 0xE6F8FF,
        }),
    },
    {
        id = "classic", room = "GATE ROOM", name = "Classic", series = "Stargate Journey",
        shape = "v", track = true, chevronWidth = 1.4,
        palette = palette({
            [colors.lightGray] = 0x8A7356, [colors.gray] = 0x4E4031, [colors.brown] = 0x6E5B44, [colors.pink] = 0xB49E7C,
            [colors.magenta] = 0x5A3A22, [colors.orange] = 0xFF7B22, [colors.yellow] = 0xFFD27A,
        }),
    },
    {
        id = "infinity", room = "STARGATE INFINITY", name = "Infinity", series = "Stargate Infinity",
        shape = "v", track = true, horizon = "spiral",
        palette = palette({
            [colors.lightGray] = 0x9EA6B0, [colors.gray] = 0x58606A, [colors.brown] = 0x7C848F, [colors.pink] = 0xC8CED6,
            [colors.magenta] = 0x4A6224, [colors.orange] = 0xC8F03C, [colors.yellow] = 0xF2FF8A,
            [colors.blue] = 0x26303C, [colors.cyan] = 0xA9C7E6, [colors.lightBlue] = 0xCFE2F4, [colors.white] = 0xF6FAFF,
        }),
    },
    {
        id = "hybrid", room = "GATE ROOM", name = "Legacy Hybrid", series = "Stargate Journey",
        shape = "v", track = true,
        -- amber, red and purple chevron pairs with a blue master chevron
        lit = { colors.orange, colors.red, colors.purple, colors.purple, colors.red, colors.orange, colors.yellow, colors.yellow },
        master = colors.lightBlue,
        palette = palette({ [colors.orange] = 0xFFB020, [colors.red] = 0xFF3B30, [colors.purple] = 0xB45CFF,
                            [colors.yellow] = 0xFFE6A0, [colors.magenta] = 0x3E2A3A }),
    },
    {
        id = "sgcraft", room = "GATE ROOM", name = "SGCraft", series = "Greg's SGCraft",
        shape = "v", track = true,
        palette = palette({ [colors.orange] = 0xFF5A20, [colors.lightGray] = 0x8E8E8E, [colors.gray] = 0x474747,
                            [colors.brown] = 0x6A6A6A, [colors.pink] = 0xB8B8B8 }),
    },
}

S.BY_ID = {}
for i, s in ipairs(S.LIST) do
    s.index = i
    s.ring = s.ring or { track = 0.86, rim = 0.70, horizon = 0.66 }
    s.chevronWidth = s.chevronWidth or 1
    s.horizon = s.horizon or "swirl"
    s.master = s.master or colors.orange
    S.BY_ID[s.id] = s
end

-- picks the style for a gate from its type and variant
local VARIANT_MATCH = {
    { "sg%-?1", "sg1" }, { "promo", "sg1" }, { "movie", "movie" }, { "atlantis", "atlantis" }, { "lantea", "atlantis" },
    { "infinity", "infinity" }, { "hybrid", "hybrid" }, { "legacy", "hybrid" }, { "destiny", "universe" },
    { "universe", "universe" }, { "tollan", "tollan" }, { "classic", "classic" },
}

function S.forGate(gate)
    if not gate then return S.BY_ID.milky_way end
    local v = gate.variant and gate.variant:lower()
    if v then
        for _, m in ipairs(VARIANT_MATCH) do
            if v:find(m[1]) then return S.BY_ID[m[2]] end
        end
    end
    return S.BY_ID[gate.typeId] or S.BY_ID.milky_way
end

-- style for a setting value ("auto" or a style id)
function S.resolve(setting, gate)
    if setting and setting ~= "auto" and S.BY_ID[setting] then return S.BY_ID[setting] end
    return S.forGate(gate)
end

-- next setting value when cycling: auto, then every style
function S.nextSetting(setting)
    if setting == nil or setting == "auto" then return S.LIST[1].id end
    local s = S.BY_ID[setting]
    if not s or s.index == #S.LIST then return "auto" end
    return S.LIST[s.index + 1].id
end

local function setPalette(t, map)
    if not t.setPaletteColour then return end
    for c, hex in pairs(map) do t.setPaletteColour(c, hex) end
end

function S.apply(t, style)
    setPalette(t, style.palette)
end

function S.reset(t)
    setPalette(t, S.DEFAULT)
end

-- colour of chevron i (1-based) when lit; total = chevrons in the address incl. point of origin
function S.chevronColor(style, i, total)
    if i == total then return style.master end
    if style.lit then return style.lit[(i - 1) % #style.lit + 1] end
    return colors.orange
end

-- palette used by the Network Hub: default hues for the portal colours, space blue background
S.HUB = {}
for k, v in pairs(S.DEFAULT) do S.HUB[k] = v end
S.HUB[colors.black] = 0x070B18
S.HUB[colors.gray] = 0x1C2440
S.HUB[colors.lightGray] = 0x8D97B5
S.HUB[colors.blue] = 0x2F6BFF
S.HUB[colors.lightBlue] = 0x7FC2FF
S.HUB[colors.cyan] = 0x2FD3E8
S.HUB[colors.purple] = 0xA45CFF
S.HUB[colors.red] = 0xF0413A
S.HUB[colors.orange] = 0xFF9A2E
S.HUB[colors.lime] = 0x6CE04A

return S
