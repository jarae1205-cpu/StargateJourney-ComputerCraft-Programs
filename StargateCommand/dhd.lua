--
--   Dial Home Device
--   A touch screen DHD for an advanced monitor (CC: Tweaked)
--
--   The DHD from the show: two rings of symbol keys around a big dome. Press
--   the symbols of an address, then the dome. Where the computer can lock one
--   symbol at a time (Stargate Journey, Chevron Seven, Lantea: Stargates), each
--   key locks its chevron as you press it, as on a real DHD, and the dome
--   engages the point of origin. On SGCraft, LanteaCraft and Just Stargate Mod
--   gates the keys build up the address and the dome dials it.
--
--   BOOK opens the address book: pick an address as the cartouche, and its
--   next key glows green, like reading the glyphs off a sheet; PRESS ALL
--   presses the rest and the dome for you.
--
--   The dome closes an open wormhole again. The look (Milky Way, Pegasus,
--   Universe, Carter Addon Pack, Infinity, LanteaCraft, JSG, SG Network and
--   SG Network Pegasus) follows the gate; the arrows at the top of the panel
--   change it.
--
--   Usage:
--     dhd              first advanced monitor, or this screen if there is none
--     dhd <monitor>    that monitor
--     dhd term         this screen
--

local VERSION = "1.1"

--
-- CONFIGURATION
--
local CONFIG = {
    -- address book shared with the Personal Dialer, the Gate Room and the Hub
    -- (the DHD only reads it, to name the gate you dial and send its iris code)
    dataFile = "dialer_addresses.db",
    -- peripheral name of the gate interface, nil = first one found
    interfaceName = nil,
    -- monitor text scale
    textScale = 0.5,
    -- the DHD's look: "milky_way", "pegasus", "universe", "carter", "infinity", "lanteacraft",
    -- "jsg", "sgnet" or "sgnet_pegasus"; nil follows the gate. The arrows on the screen
    -- change it and it is remembered
    look = nil,
    -- send the address book entry's iris code when the wormhole opens
    sendCodes = true,
    -- with a wireless or ender modem, pass travellers' GDO codes through the wormhole
    gdoRelay = true,
    -- key clicks on an attached speaker
    clicks = true,
    -- how long to wait for the gate
    stepTimeout = 60,
    connectTimeout = 10,
    chevronDelay = 0.4,
    pollInterval = 1,
}
--
-- END OF CONFIGURATION
--

local A = require("sgc.address")
local Book = require("sgc.book")
local Gate = require("sgc.gate")
local D = require("sgc.dhd")
local Glyphs = require("sgc.glyphs")
local IDC = require("sgc.idc")
local Pixels = require("sgc.pixels")
local Styles = require("sgc.styles")
local UI = require("sgc.ui")

local hasGdoLib, GDO = pcall(require, "sgc.gdo")
if not hasGdoLib then GDO = nil end

local args = { ... }
local floor, ceil, sqrt, pi = math.floor, math.ceil, math.sqrt, math.pi
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local fit, pad = UI.fit, UI.pad

---------------------------------------------------------------------------
-- Looks
---------------------------------------------------------------------------
--
-- Every look recolours the same palette slots:
--   black      screen              white      bright text, dome highlight
--   gray       the DHD's body      purple     its rim
--   green      gaps between keys   brown      key
--   pink       symbol on a key     orange     lit key, accent
--   yellow     symbol on a lit key magenta    dome
--   cyan       lit dome            red        alarm
--   lightGray  dim text            lime       ok
--   blue, lightBlue  the wormhole
--

local PANEL = {
    [colors.black] = 0x0A0B0E, [colors.white] = 0xF2F4F8, [colors.lightGray] = 0x8E939C,
    [colors.lime] = 0x6FD34A, [colors.blue] = 0x0B3C9E, [colors.lightBlue] = 0x8CC4FF, [colors.red] = 0xE0301E,
}

local function look(id, name, over)
    local p = {}
    for k, v in pairs(PANEL) do p[k] = v end
    for k, v in pairs(over) do p[k] = v end
    return { id = id, name = name, palette = p }
end

local LOOKS = {
    -- the SGC's DHD: dark stone, sand coloured keys with carved symbols, an amber glow and a red dome
    look("milky_way", "Milky Way", {
        [colors.gray] = 0x3B3632, [colors.purple] = 0x221F1C, [colors.green] = 0x171513,
        [colors.brown] = 0x8C8372, [colors.pink] = 0x3A342C,
        [colors.orange] = 0xFFA032, [colors.yellow] = 0xFFF1B8,
        [colors.magenta] = 0x5E1610, [colors.cyan] = 0xFF3B1F,
    }),
    -- Atlantis: a slate console whose symbols light blue
    look("pegasus", "Pegasus", {
        [colors.gray] = 0x1F2731, [colors.purple] = 0x10161D, [colors.green] = 0x0B1015,
        [colors.brown] = 0x2C3946, [colors.pink] = 0x5E87AC,
        [colors.orange] = 0x2F86FF, [colors.yellow] = 0xE2F4FF,
        [colors.magenta] = 0x123866, [colors.cyan] = 0x4FB4FF,
    }),
    -- Destiny's gates light white; so does this DHD
    look("universe", "Universe", {
        [colors.gray] = 0x1A1C20, [colors.purple] = 0x0E0F12, [colors.green] = 0x08090B,
        [colors.brown] = 0x30333A, [colors.pink] = 0x737985,
        [colors.orange] = 0xE6EBF5, [colors.yellow] = 0x20232A,
        [colors.magenta] = 0x2A2D33, [colors.cyan] = 0xF4F7FF,
    }),
    -- Carter's Addon Pack: an orange DHD with a blue dome
    look("carter", "Carter Addon Pack", {
        [colors.gray] = 0xA9501C, [colors.purple] = 0x5C2A0C, [colors.green] = 0x3E1B06,
        [colors.brown] = 0xD9792F, [colors.pink] = 0x5A2A08,
        [colors.orange] = 0xFFD45A, [colors.yellow] = 0x6A3200,
        [colors.magenta] = 0x163F86, [colors.cyan] = 0x54C2FF,
    }),
    -- the cartoon: pale blue-grey with ink outlines, lime-yellow when lit
    look("infinity", "Infinity", {
        [colors.gray] = 0x6E7B8C, [colors.purple] = 0x111418, [colors.green] = 0x111418,
        [colors.brown] = 0xC8D2DE, [colors.pink] = 0x22262C,
        [colors.orange] = 0xD4F23C, [colors.yellow] = 0x1A1F10,
        [colors.magenta] = 0x3C6C80, [colors.cyan] = 0xBDF6FF,
    }),
    -- LanteaCraft's DHD: a charcoal console, dark keys with pale carved symbols, amber light
    -- like its gate's chevrons, and a glossy orange-red dome
    look("lanteacraft", "LanteaCraft", {
        [colors.gray] = 0x2B2B2E, [colors.purple] = 0x121214, [colors.green] = 0x0C0C0D,
        [colors.brown] = 0x404145, [colors.pink] = 0xA7A9AE,
        [colors.orange] = 0xF0A526, [colors.yellow] = 0xFFF3C8,
        [colors.magenta] = 0x5A1A0E, [colors.cyan] = 0xF0552A,
    }),
    -- Just Stargate Mod (and Aunis before it): a black DHD, dark keys with grey symbols,
    -- orange light like its chevrons and a deep red dome
    look("jsg", "JSG", {
        [colors.gray] = 0x1F1F21, [colors.purple] = 0x0E0E10, [colors.green] = 0x080809,
        [colors.brown] = 0x2F2F33, [colors.pink] = 0x8C8C93,
        [colors.orange] = 0xFF7424, [colors.yellow] = 0xFFF0D2,
        [colors.magenta] = 0x5C0B09, [colors.cyan] = 0xFF2B1C,
    }),
    -- SGCraft 2.x, the "Stargate Network" mod (1.12.2): a dark stone DHD with pale symbols
    -- and an orange dome
    look("sgnet", "SG Network", {
        [colors.gray] = 0x2A2927, [colors.purple] = 0x161514, [colors.green] = 0x0D0C0C,
        [colors.brown] = 0x3E3C39, [colors.pink] = 0xB3AFA7,
        [colors.orange] = 0xFF6F1E, [colors.yellow] = 0xFFF0C8,
        [colors.magenta] = 0x6A2806, [colors.cyan] = 0xFF9A1E,
    }),
    -- its Pegasus DHD: the same dark console with symbols that light blue and a blue dome
    look("sgnet_pegasus", "SG Network Pegasus", {
        [colors.gray] = 0x22252A, [colors.purple] = 0x111317, [colors.green] = 0x0A0B0D,
        [colors.brown] = 0x33373E, [colors.pink] = 0x8DB3D6,
        [colors.orange] = 0x3FB0FF, [colors.yellow] = 0xE6F6FF,
        [colors.magenta] = 0x0E3260, [colors.cyan] = 0x46B4FF,
    }),
}
local LOOK_BY_ID = {}
for i, l in ipairs(LOOKS) do
    l.index = i
    LOOK_BY_ID[l.id] = l
end

-- the look for a gate: its type, or a variant named after one
local function lookFor(g)
    if not g then return LOOK_BY_ID.milky_way end
    if g.mod == "lanteacraft" or g.mod == "lanteacraft17" then return LOOK_BY_ID.lanteacraft end
    if (g.mod == "jsg" or g.mod == "jsg112") and g.typeId == "milky_way" and not g.variant then return LOOK_BY_ID.jsg end
    if g.mod == "sgcraft" and g.hasZpm and not g.variant then return LOOK_BY_ID.sgnet end
    local v = (g.variant or ""):lower()
    -- Chevron Seven's looks after other mods ("chevron7:jsg120", "chevron7:sgcraft")
    if v:find("jsg") then return LOOK_BY_ID.jsg end
    if v:find("sgcraft") then return LOOK_BY_ID.sgnet end
    if v:find("infinity") then return LOOK_BY_ID.infinity end
    if v:find("carter") or v:find("%f[%a]cap%f[%A]") then return LOOK_BY_ID.carter end
    if v:find("atlantis") or v:find("lantea") then return LOOK_BY_ID.pegasus end
    if v:find("destiny") then return LOOK_BY_ID.universe end
    return LOOK_BY_ID[g.typeId] or LOOK_BY_ID.milky_way
end

---------------------------------------------------------------------------
-- Screen
---------------------------------------------------------------------------

local native = term.current()
local monitor, monitorName
if args[1] ~= "term" then
    if args[1] then
        monitor = peripheral.wrap(args[1])
        if not monitor or peripheral.getType(args[1]) ~= "monitor" then error("No monitor called " .. args[1], 0) end
    else
        monitor = peripheral.find("monitor", function(_, m) return m.isColor() end)
    end
    if monitor then
        if not monitor.isColor() then error("The DHD needs an advanced monitor", 0) end
        monitorName = peripheral.getName(monitor)
        monitor.setTextScale(CONFIG.textScale)
    end
end
local target = monitor or native
if not target.isColor() then error("The DHD needs an advanced computer or monitor", 0) end
local ui = UI.new(target)

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local book = Book.open(CONFIG.dataFile)
local gate = Gate.find(CONFIG.interfaceName)
if gate and (gate.mod == "lanteacraft" or gate.mod == "lanteacraft17") then A.plainLetters = true end
local keyset = D.keys(gate)

local lookSetting = CONFIG.look or settings.get("dhd.look")
local style = LOOK_BY_ID[lookSetting] or lookFor(gate)

-- the address on the keys, in the order pressed: { symbol = ..., state = "queued" | "engaging" | "locked" }
local seq = {}
-- the dome: nil, "engaging" (the point of origin is going in) or "dialing" (a queued dial is running)
local dome = nil
-- jobs for the gate, run one after another by the worker: { kind = "key", entry } | { kind = "origin" } | { kind = "dial" }
local work = { queue = {}, busy = false, abort = false, gen = 0, current = nil }
local input = ""                        -- what is being typed on the keyboard
-- the cartouche: an address book entry whose symbols the keys show, in order
-- { name = "Abydos", symbols = { 26, 6, 14, 31, 11, 29 } }
local guide = nil
local bookView = nil                    -- { page = 1 } while the address book is on the screen
local message = { text = "", color = colors.lightGray }
local lastState = gate and gate.state or "OFFLINE"
local codeSent = false                  -- this wormhole's iris code went out
local running = true
local blink = false                     -- flips every tick, for whatever is blinking
local speaker = peripheral.find("speaker")
local relay = nil

local W, H, L

local function setMessage(text, color)
    message.text = text or ""
    message.color = color or colors.lightGray
end

local function click(kind)
    if not (CONFIG.clicks and speaker) then return end
    if kind == "dome" then
        pcall(speaker.playNote, "basedrum", 1, 6)
    elseif kind == "error" then
        pcall(speaker.playNote, "bass", 1, 2)
    else
        pcall(speaker.playNote, "hat", 0.8, 16)
    end
end

local function symbols()
    local list = {}
    for i, e in ipairs(seq) do list[i] = e.symbol end
    return list
end

local function inSeq(symbol)
    for i, e in ipairs(seq) do
        if e.symbol == symbol then return i end
    end
    return nil
end

local function busy()
    return work.busy or #work.queue > 0
end

-- the address book entry the keys spell, if any
local function matchEntry()
    if #seq == 0 or not keyset.lengths[#seq] then return nil end
    return book:find(D.address(keyset, symbols()))
end

local function symbolText(symbol)
    if symbol == keyset.origin then return "Point of Origin" end
    return tostring(symbol)
end

-- the keys for an address book entry, in order; or nil and why it can't be dialed from them
local function cartoucheFor(entry)
    if not entry or not entry.address then return nil, ((entry and entry.name) or "That entry") .. " has no address yet" end
    if not gate then return nil, "No stargate interface connected" end
    if keyset.why then return nil, keyset.why end
    local ok, why = A.dialableBy(entry.address, gate.mod)
    if not ok then return nil, why end
    local list = {}
    for i, s in ipairs(A.symbols(entry.address)) do
        local key
        for _, k in ipairs(keyset.symbols) do
            if k == s or (type(k) == "string" and type(s) == "string" and k:lower() == s:lower()) then key = k break end
        end
        if key == nil then return nil, tostring(s) .. " isn't one of this gate's keys" end
        list[i] = key
    end
    if not keyset.lengths[#list] then return nil, "This gate's addresses have " .. D.lengthText(keyset) .. " symbols" end
    return list
end

-- the address book entries the keys can dial, listed at this gate
local function cartouches()
    local out = {}
    for _, e in ipairs(book:visible(gate and gate.localAddress)) do
        if cartoucheFor(e) then out[#out + 1] = e end
    end
    return out
end

-- the cartouche's next symbol; nil, true when the keys have left the cartouche
local function guideNext()
    if not guide then return nil end
    for i, e in ipairs(seq) do
        if e.symbol ~= guide.symbols[i] then return nil, true end
    end
    return guide.symbols[#seq + 1]
end

local function startRelay()
    if relay or not (GDO and CONFIG.gdoRelay) then return end
    relay = GDO.newRelay(function() return gate end)
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

local PANEL_MIN = 24  -- width of the panel next to a round DHD
local ROUND_MIN = 40  -- radius in pixels the round DHD needs; smaller screens get a keypad

-- the rings, as fractions of the DHD's radius
local RING = {
    dome = 0.35,
    inner = { 0.40, 0.68 },
    outer = { 0.71, 0.97 },
}

-- pixel classes of the round DHD
local C_BG, C_BODY, C_RIM, C_GAP, C_DOME, C_SHINE, C_DOME_RIM, C_GLINT = 0, 1, 2, 3, 4, 5, 6, 7
local C_KEY = 100 -- C_KEY + key index

local function buildRound()
    local cols, rows = L.cols, L.rows
    local canvas = Pixels.new(cols, rows, colors.black)
    local w, h = canvas.w, canvas.h
    local R = L.R
    local cx, cy = w / 2 + 0.5, h / 2 + 0.5
    local n = #keyset.symbols
    local nOuter = ceil(n / 2)
    local nInner = n - nOuter
    local map = {}
    local rD = RING.dome * R
    local i1, i2 = RING.inner[1] * R, RING.inner[2] * R
    local o1, o2 = RING.outer[1] * R, RING.outer[2] * R
    -- the shine on the dome: a spot up and to the left of its middle
    local sx, sy, sr = cx - rD * 0.38, cy - rD * 0.42, rD * 0.30
    for y = 1, h do
        for x = 1, w do
            local dx, dy = x - cx, y - cy
            local r = sqrt(dx * dx + dy * dy)
            local c = C_BG
            if r <= R then
                c = C_BODY
                if r > R - 1.6 then
                    c = C_RIM
                elseif r <= rD then
                    c = C_DOME
                    if r > rD - 1.3 then
                        c = C_DOME_RIM
                    elseif (x - sx) ^ 2 + (y - sy) ^ 2 <= (sr * 0.5) ^ 2 then
                        c = C_GLINT
                    elseif (x - sx) ^ 2 + (y - sy) ^ 2 <= sr * sr then
                        c = C_SHINE
                    end
                else
                    local count, first, ring
                    if r >= o1 and r <= o2 then
                        count, first = nOuter, 0
                    elseif r >= i1 and r <= i2 and nInner > 0 then
                        count, first = nInner, nOuter
                    end
                    if count then
                        -- key 1 of a ring is at the top, the others follow clockwise
                        local t = ((atan2(dy, dx) + pi / 2) / (2 * pi) * count + 0.5) % count
                        local k = floor(t)
                        local frac = t - k
                        local edge = math.min(frac, 1 - frac) * 2 * pi * r / count
                        if edge < 0.8 then c = C_GAP else c = C_KEY + first + k + 1 end
                    end
                end
            end
            map[(y - 1) * w + x] = c
        end
    end
    -- where each key's symbol and label go
    local keys = {}
    local function place(index, ringIndex, count, rr)
        local a = -pi / 2 + (ringIndex - 1) * 2 * pi / count
        local mid = (rr[1] + rr[2]) / 2 * R
        local thick = (rr[2] - rr[1]) * R
        local arc = 2 * pi * mid / count
        local size = floor(math.min(thick, arc) * 0.62)
        local gx, gy = cx + math.cos(a) * mid, cy + math.sin(a) * mid
        keys[index] = {
            glyph = { floor(gx - size / 2 + 0.5), floor(gy - size / 2 + 0.5), size },
            -- the label: the character cell at the middle of the key
            lx = floor((gx - 0.5) / 2) + 1, ly = floor((gy - 0.5) / 3) + 1,
            width = floor(arc / 2),
        }
    end
    for i = 1, nOuter do place(i, i, nOuter, RING.outer) end
    for i = 1, nInner do place(nOuter + i, i, nInner, RING.inner) end
    L.canvas, L.map, L.keys = canvas, map, keys
end

local function layout()
    W, H = target.getSize()
    L = {}
    -- the biggest round DHD that leaves room for the panel
    local R = floor(math.min(H * 3, (W - PANEL_MIN - 1) * 2) / 2) - 1
    if R >= ROUND_MIN then
        L.mode = "round"
        L.R = R
        L.cols = math.min(W - PANEL_MIN - 1, ceil((2 * R + 3) / 2))
        L.rows = H
        L.px = L.cols + 2
        L.pw = W - L.px
        buildRound()
    else
        L.mode = "keypad"
    end
    target.setBackgroundColor(colors.black)
    target.clear()
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

local function queueJob(job)
    work.queue[#work.queue + 1] = job
    os.queueEvent("dhd_work")
end

-- stops what the worker is doing and forgets the jobs still waiting
local function dropJobs()
    work.abort = true
    work.queue = {}
    if work.current ~= "origin" and work.current ~= "dial" then dome = nil end
end

-- forget the address on the keys
local function resetKeys()
    seq, dome, input = {}, nil, ""
end

local function pressKey(symbol)
    if keyset.why then setMessage(keyset.why, colors.orange) click("error") return end
    if not gate then setMessage("No stargate interface connected", colors.red) click("error") return end
    local st = gate.state
    if st == "OPEN" then setMessage("The wormhole is open - press the dome to close it", colors.orange) click("error") return end
    if st == "INCOMING" then setMessage("Incoming wormhole - the keys are locked", colors.red) click("error") return end
    if st == "CLOSING" then setMessage("The gate is closing", colors.orange) click("error") return end
    if st == "OFFLINE" then setMessage("The gate is offline", colors.red) click("error") return end
    if dome then setMessage("Dialing - CLEAR stops it", colors.orange) click("error") return end
    if st == "DIALING" and not keyset.direct then setMessage("The gate is dialing", colors.orange) click("error") return end
    -- letters may repeat in SGCraft and LanteaCraft addresses ("WLDQDQBMT")
    local at = keyset.kind ~= "letters" and inSeq(symbol)
    if at then
        if not keyset.direct and at == #seq then
            -- a key that has not gone to the gate yet can be taken back
            table.remove(seq)
            click()
            setMessage("Took back " .. tostring(symbol), colors.lightGray)
            return
        end
        setMessage(tostring(symbol) .. " is already in the address", colors.orange)
        click("error")
        return
    end
    if #seq >= keyset.max then
        setMessage("An address has at most " .. keyset.max .. " symbols - press the dome", colors.orange)
        click("error")
        return
    end
    local wanted = guideNext()
    local entry = { symbol = symbol, state = "queued" }
    seq[#seq + 1] = entry
    click()
    if keyset.direct then
        queueJob({ kind = "key", entry = entry })
        setMessage("")
    elseif keyset.lengths[#seq] then
        setMessage("Press the dome to dial", colors.lightGray)
    else
        setMessage("")
    end
    if wanted ~= nil and symbol ~= wanted then
        setMessage("The cartouche for " .. guide.name .. " has " .. symbolText(wanted) .. " here", colors.orange)
    end
end

-- takes back the symbols from line n of the address on, if they haven't gone to the gate
local function takeBack(n)
    if keyset.direct or dome or not seq[n] then return end
    if gate and gate.state ~= "IDLE" then return end
    local gone = {}
    for i = #seq, n, -1 do table.insert(gone, 1, D.label(table.remove(seq, i).symbol)) end
    click()
    setMessage("Took back " .. table.concat(gone, keyset.kind == "letters" and "" or " "), colors.lightGray)
end

local function closeGate()
    if busy() or dome then dropJobs() end
    local ok, why = gate:close()
    if ok == false and why then
        setMessage(tostring(why), colors.orange)
    else
        setMessage("Closing the wormhole", colors.lightGray)
    end
end

local function pressDome()
    click("dome")
    if keyset.why then setMessage(keyset.why, colors.orange) return end
    if not gate then setMessage("No stargate interface connected", colors.red) return end
    gate:poll()
    local st = gate.state
    if gate.connected or st == "OPEN" or st == "INCOMING" and gate.connected then
        closeGate()
        return
    end
    if st == "INCOMING" then setMessage("Incoming wormhole", colors.red) return end
    if st == "CLOSING" then setMessage("The gate is closing", colors.orange) return end
    if dome then setMessage("Dialing - CLEAR stops it", colors.orange) return end
    local n = #seq
    if n == 0 then
        setMessage("Press the symbols of an address, then the dome", colors.lightGray)
        return
    end
    if not keyset.lengths[n] then
        setMessage("An address has " .. D.lengthText(keyset) .. " symbols; this one has " .. n, colors.orange)
        return
    end
    book:reload()
    if keyset.direct then
        dome = "engaging"
        queueJob({ kind = "origin" })
        setMessage("Engaging the point of origin", colors.lightGray)
    else
        local address = D.address(keyset, symbols())
        local ok, why = A.dialableBy(address, gate.mod)
        if not ok then setMessage(why, colors.red) return end
        dome = "dialing"
        local entry = book:find(address)
        queueJob({ kind = "dial", address = address })
        setMessage("Dialing " .. (entry and entry.name or A.format(address)), colors.lightGray)
    end
end

-- CLEAR: stop dialing and let go of the chevrons
local function clearKeys()
    local had = #seq > 0 or busy() or dome
    dropJobs()
    work.gen = work.gen + 1
    if gate then
        gate:poll()
        if gate.state == "DIALING" or (gate.state ~= "INCOMING" and not gate.connected and (gate.chevrons or 0) > 0) then
            gate:close()
        end
    end
    resetKeys()
    setMessage(had and "Cleared" or "", colors.lightGray)
end

-- PRESS ALL: the cartouche's remaining symbols, then the dome
local function pressAll()
    if not guide then return end
    local _, off = guideNext()
    if off then setMessage("The keys have left the cartouche - CLEAR, then PRESS ALL", colors.orange) return end
    for i = #seq + 1, #guide.symbols do
        local before = #seq
        pressKey(guide.symbols[i])
        if #seq == before then return end -- refused, and pressKey said why
    end
    pressDome()
end

local function pickCartouche(entry)
    bookView = nil
    if not entry then
        guide = nil
        setMessage("No cartouche", colors.lightGray)
        return
    end
    local list, why = cartoucheFor(entry)
    if not list then setMessage(why, colors.orange) return end
    guide = { name = entry.name, symbols = list }
    local _, off = guideNext()
    setMessage(off and ("Cartouche: " .. entry.name .. " - CLEAR the keys to follow it")
        or ("Cartouche: " .. entry.name .. " - press the green keys, or " .. (L.mode == "round" and "PRESS ALL" or "ALL")), colors.lime)
end

local function toggleBook()
    if bookView then
        bookView = nil
    else
        book:reload()
        bookView = { page = 1 }
    end
end

local function toggleIris()
    if not gate then return end
    local ok, err = gate:toggleIris()
    if ok == false then setMessage(tostring(err), colors.orange) end
end

local function cycleLook(step)
    local i = (style.index - 1 + step) % #LOOKS + 1
    style = LOOKS[i]
    settings.set("dhd.look", style.id)
    pcall(settings.save)
    Styles.apply(target, style)
    if L.canvas then L.canvas:invalidate() end
    target.setBackgroundColor(colors.black)
    target.clear()
end

-- sends the dialed entry's iris code through the wormhole we just opened
local function sendCode()
    if codeSent or not CONFIG.sendCodes or not gate then return end
    codeSent = true
    local address = gate.remote or (#seq > 0 and D.address(keyset, symbols())) or nil
    local entry = address and book:find(address)
    if not (entry and entry.idc) then return end
    if gate.mod == "lanteacraft" then
        setMessage("Wormhole open to " .. entry.name .. " - send code " .. entry.idc .. " with your GDO", colors.lightBlue)
        return
    end
    local ok, why = gate:sendMessage(IDC.message(entry.idc))
    if ok then
        setMessage("Wormhole open to " .. entry.name .. " - iris code sent", colors.lightBlue)
    else
        setMessage("Wormhole open to " .. entry.name .. " - could not send the iris code: " .. tostring(why), colors.orange)
    end
end

-- the keys follow the gate when someone else dials it (the DHD block, another computer)
local function followGate()
    if not gate then return end
    local st = gate.state
    if st ~= lastState then
        if st == "IDLE" and lastState ~= "OFFLINE" and not busy() then
            resetKeys()
            -- the trip is over: the cartouche goes back in the book
            if lastState == "OPEN" or lastState == "CLOSING" then guide = nil end
        end
        if st ~= "OPEN" then codeSent = false end
        lastState = st
    end
    if busy() or dome then return end
    if st == "DIALING" or st == "INCOMING" or st == "OPEN" then
        local eng = gate.engaged or {}
        local count = 0
        for i = 1, #eng do
            if eng[i] == nil then break end
            count = i
        end
        if count > 0 and count >= #seq then
            local same = true
            for i = 1, #seq do
                if seq[i].symbol ~= eng[i] then same = false end
            end
            if not same or count > #seq then
                seq = {}
                for i = 1, count do
                    if not D.isOrigin(keyset, eng[i]) then seq[#seq + 1] = { symbol = eng[i], state = "locked" } end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local STATE_TEXT = {
    IDLE = { "IDLE", colors.gray, colors.lightGray },
    DIALING = { "DIALING", colors.orange, colors.black },
    OPEN = { "WORMHOLE OPEN", colors.lightBlue, colors.black },
    INCOMING = { "INCOMING WORMHOLE", colors.red, colors.white },
    CLOSING = { "CLOSING", colors.gray, colors.white },
    OFFLINE = { "GATE OFFLINE", colors.red, colors.white },
}

local function keyState(symbol)
    local i = inSeq(symbol)
    if not i then return nil end
    return seq[i].state
end

-- the status badge: text, background, text colour
local function status()
    if not gate then return "NO GATE", colors.red, colors.white end
    local st = gate.state
    if st == "INCOMING" then
        return gate.connected and "INCOMING WORMHOLE" or "INCOMING", blink and colors.red or colors.black, blink and colors.white or colors.red
    end
    if st == "OPEN" then
        local s = gate:openSeconds()
        return "WORMHOLE OPEN" .. (s and ("  " .. UI.duration(s)) or ""), colors.lightBlue, colors.black
    end
    if st == "DIALING" or dome then
        local locked = 0
        for _, e in ipairs(seq) do if e.state == "locked" then locked = locked + 1 end end
        if dome == "engaging" then return "ENGAGING", colors.orange, colors.black end
        if locked > 0 then return "CHEVRON " .. locked .. " LOCKED", colors.orange, colors.black end
        return "DIALING", colors.orange, colors.black
    end
    if st == "IDLE" and #seq > 0 then
        if keyset.lengths[#seq] then return "ADDRESS READY", colors.orange, colors.black end
        return "ADDRESS " .. #seq .. " OF " .. keyset.max, colors.gray, colors.white
    end
    local t = STATE_TEXT[st] or STATE_TEXT.IDLE
    return t[1], t[2], t[3]
end

-- the second line of the status badge: what to do next
local function hint()
    if not gate or keyset.why then return "" end
    if gate.connected then return "the dome closes it" end
    if gate.state == "INCOMING" then return "keys are locked" end
    if dome then return "CLEAR stops it" end
    local pending = false
    for _, e in ipairs(seq) do if e.state ~= "locked" and keyset.direct then pending = true end end
    if #seq > 0 and keyset.lengths[#seq] and not pending then return "press the dome to dial" end
    return keyset.direct and "keys lock as pressed" or "the dome dials"
end

local function drawRound()
    local canvas, map, px = L.canvas, L.map, L.canvas.px
    local IDX = Pixels.index
    local lit = gate and gate.connected
    local domeLit = lit or (dome and blink)
    local colorOf = {
        [C_BG] = IDX[colors.black], [C_BODY] = IDX[colors.gray], [C_RIM] = IDX[colors.purple],
        [C_GAP] = IDX[colors.green],
        [C_DOME] = IDX[domeLit and colors.cyan or colors.magenta],
        [C_SHINE] = IDX[domeLit and colors.white or colors.magenta],
        [C_GLINT] = IDX[domeLit and colors.white or colors.cyan],
        [C_DOME_RIM] = IDX[colors.purple],
    }
    local n = #keyset.symbols
    local keyFace, keyInk = {}, {}
    local nextKey = not dome and guideNext() or nil
    for i, s in ipairs(keyset.symbols) do
        local st = keyState(s)
        -- keys waiting for the gate blink; keys still to be dialed by the dome stay lit
        local waiting = st == "engaging" or (st == "queued" and (keyset.direct or dome ~= nil))
        local on = st == "locked" or (st == "queued" and not waiting) or (waiting and blink)
        keyFace[i] = on and colors.orange or colors.brown
        keyInk[i] = on and colors.yellow or colors.pink
        if s == nextKey and not on then keyFace[i], keyInk[i] = colors.lime, colors.purple end
        colorOf[C_KEY + i] = IDX[keyFace[i]]
    end
    for i = 1, canvas.w * canvas.h do
        px[i] = colorOf[map[i]] or 0
    end
    for i = 1, n do
        local k = L.keys[i]
        local g = k.glyph
        if g[3] >= 4 then Glyphs.draw(canvas, keyset.symbols[i], g[1], g[2], g[3], g[3], keyInk[i], g[3] >= 18 and 2 or 1) end
    end
    canvas:draw(target, 1, 1)
    -- the labels
    for i, s in ipairs(keyset.symbols) do
        local k = L.keys[i]
        local text = D.label(s)
        if #text > k.width then text = text:sub(1, math.max(1, k.width)) end
        local x = k.lx - floor((#text - 1) / 2)
        ui:write(x, k.ly, text, (keyFace[i] == colors.orange or keyFace[i] == colors.lime) and colors.purple or colors.pink, keyFace[i])
    end
end

-- the address book on the screen: tap an entry to make it the cartouche
local function drawBook(x, y, w, h)
    local list = cartouches()
    ui:fill(x, y, w, h, colors.black)
    ui:write(x, y, fit("PICK A CARTOUCHE", w), colors.white, colors.black)
    local per = math.max(1, h - 2 - (guide and 1 or 0))
    local pages = math.max(1, ceil(#list / per))
    bookView.page = math.max(1, math.min(bookView.page, pages))
    local yy = y + 1
    if guide then
        ui:write(x, yy, pad("(no cartouche)", w), colors.lightGray, colors.black)
        ui:hit(x, yy, x + w - 1, yy, function() pickCartouche(nil) end)
        yy = yy + 1
    end
    if #list == 0 then
        ui:write(x, yy, fit("No address this gate can dial", w), colors.lightGray, colors.black)
    end
    for i = 1, per do
        local e = list[(bookView.page - 1) * per + i]
        if not e then break end
        local on = guide and guide.name == e.name
        ui:write(x, yy, pad(e.name, w), on and colors.lime or colors.white, colors.black)
        ui:hit(x, yy, x + w - 1, yy, function() pickCartouche(e) end)
        yy = yy + 1
    end
    local ly = y + h - 1
    ui:fill(x, ly, w, 1, colors.gray)
    if pages > 1 then
        local nav = "< " .. bookView.page .. "/" .. pages .. " >"
        ui:write(x, ly, nav, colors.white, colors.gray)
        ui:hit(x, ly, x + 1, ly, function() bookView.page = bookView.page - 1 end)
        ui:hit(x + #nav - 2, ly, x + #nav - 1, ly, function() bookView.page = bookView.page + 1 end)
    end
    ui:write(x + w - 5, ly, "CLOSE", colors.white, colors.gray)
    ui:hit(x + w - 5, ly, x + w - 1, ly, toggleBook)
end

-- CLEAR, BOOK and IRIS side by side
local function drawSmallButtons(x, y, w)
    local bw = floor((w - 2) / 3)
    local function label(long, short, width) return #long <= width and long or short end
    ui:bigButton(x, y, bw, label("CLEAR", "CLR", bw), colors.white, colors.gray, clearKeys)
    ui:bigButton(x + bw + 1, y, bw, label("BOOK", "BK", bw), bookView and colors.black or colors.white,
        bookView and colors.lime or colors.gray, toggleBook)
    ui:bigButton(x + 2 * bw + 2, y, w - 2 * bw - 2, label("IRIS", "IR", w - 2 * bw - 2), colors.white,
        (gate and gate.hasIris) and colors.gray or colors.black, toggleIris)
end

local function drawPanel()
    local x, w = L.px, L.pw
    local y = 1
    ui:fill(x - 1, 1, w + 2, H, colors.black)
    ui:fill(x, y, w, 1, colors.orange)
    ui:center(x, y, w, "DIAL HOME DEVICE", colors.black, colors.orange)
    y = y + 2
    -- the look, like the tabs of a glyph sheet
    ui:write(x, y, "<", colors.orange, colors.black)
    ui:center(x + 1, y, w - 2, style.name, colors.white, colors.black)
    ui:write(x + w - 1, y, ">", colors.orange, colors.black)
    ui:hit(x, y, x + 1, y, function() cycleLook(-1) end)
    ui:hit(x + 2, y, x + w - 1, y, function() cycleLook(1) end)
    y = y + 1
    if gate then
        ui:write(x, y, fit(gate.typeName == "Stargate" and "Stargate" or (gate.typeName .. " gate"), w), colors.lightGray, colors.black)
        ui:write(x, y + 1, fit(gate.interfaceName, w), colors.lightGray, colors.black)
        if gate.localAddress then ui:write(x, y + 2, fit(A.format(gate.localAddress), w), colors.lightGray, colors.black) end
    else
        ui:write(x, y, fit("No stargate interface", w), colors.red, colors.black)
    end
    y = y + 4

    local text, bg, fg = status()
    ui:fill(x, y, w, 2, bg)
    ui:center(x, y, w, text, fg, bg)
    ui:center(x, y + 1, w, hint(), fg, bg)
    y = y + 3

    local by = H - 4
    if bookView then
        drawBook(x, y, w, by - 1 - y)
        y = by - 1
    else
        -- the address, a line per chevron
        local rows = keyset.max + (keyset.origin ~= nil and 1 or 0)
        local remote = gate and gate.state == "INCOMING" and gate.remote
        local nextKey, off = guideNext()
        local following = guide and not off and not remote
        if following then
            local canAll = nextKey ~= nil and not dome and gate and gate.state ~= "INCOMING" and not gate.connected
            local bw = canAll and 9 or 0
            ui:write(x, y, pad(fit(guide.name, w - bw - 1), w - bw), colors.lime, colors.black)
            if canAll then
                ui:write(x + w - bw, y, "PRESS ALL", colors.black, colors.lime)
                ui:hit(x + w - bw, y, x + w - 1, y, pressAll)
            end
            rows = #guide.symbols + (keyset.origin ~= nil and 1 or 0)
        elseif guide and off and not remote then
            ui:write(x, y, fit("Off the cartouche: " .. guide.name, w), colors.orange, colors.black)
        elseif remote then
            ui:write(x, y, fit("From " .. book:describe(remote), w), colors.red, colors.black)
        else
            local entry = matchEntry()
            if entry then
                ui:write(x, y, fit("To " .. entry.name, w), colors.lime, colors.black)
            elseif #seq > 0 and keyset.lengths[#seq] then
                ui:write(x, y, fit("Not in the address book", w), colors.lightGray, colors.black)
            else
                ui:write(x, y, "ADDRESS", colors.lightGray, colors.black)
            end
        end
        y = y + 1
        local originRow = keyset.origin ~= nil and (following and #guide.symbols + 1 or #seq + 1) or nil
        for i = 1, rows do
            if y > H - 5 then break end
            local e = seq[i]
            local label, fg = "", colors.gray
            if e then
                label = symbolText(e.symbol)
                if e.state == "locked" then fg = colors.orange
                elseif e.state == "engaging" then fg = blink and colors.white or colors.orange
                else fg = keyset.direct and colors.lightGray or colors.white end
                -- a symbol that hasn't gone to the gate can be taken back from its line
                if not keyset.direct and not dome then
                    local n = i
                    ui:hit(x, y, x + w - 1, y, function() takeBack(n) end)
                end
            elseif i == originRow and (dome or (gate and gate.connected and gate.outgoing)) then
                label = symbolText(keyset.origin)
                fg = (gate and gate.connected) and colors.orange or (blink and colors.white or colors.orange)
            elseif following and guide.symbols[i] then
                -- the cartouche's symbols still to press, the next one in green
                label = symbolText(guide.symbols[i]) .. (i == #seq + 1 and "  <" or "")
                fg = i == #seq + 1 and colors.lime or colors.gray
            elseif following and i == originRow then
                label = symbolText(keyset.origin) .. (#seq == #guide.symbols and "  < the dome" or "")
                fg = #seq == #guide.symbols and colors.lime or colors.gray
            elseif i == #seq + 1 then
                label = "_"
                fg = colors.lightGray
            end
            ui:write(x, y, string.format("%d ", i), colors.lightGray, colors.black)
            ui:write(x + 2, y, pad(label, w - 2), fg, colors.black)
            y = y + 1
        end
    end

    -- the message, at most four lines above the buttons
    local my = math.max(y + 1, by - 5)
    if input ~= "" and my - 1 > y then
        ui:write(x, my - 1, fit("Typed: " .. input .. "_", w), colors.yellow, colors.black)
    end
    local lines = UI.wrap(message.text, w)
    for i = 1, math.min(4, #lines, by - 1 - my) do
        ui:write(x, my + i - 1, lines[i], message.color, colors.black)
    end

    -- buttons
    local domeLabel = "DIAL"
    if gate and gate.connected then domeLabel = "CLOSE"
    elseif dome then domeLabel = "DIALING" end
    ui:bigButton(x, by, w, domeLabel, colors.black, gate and gate.connected and colors.red or colors.orange, pressDome)
    drawSmallButtons(x, by + 3, w)
end

-- small screens: the keys as a keypad
local function drawKeypad()
    target.setBackgroundColor(colors.black)
    target.clear()
    ui:fill(1, 1, W, 1, colors.orange)
    ui:write(2, 1, fit("DHD", W), colors.black, colors.orange)
    local tabText = "< " .. style.name .. " >"
    local tx = W - #tabText
    if tx > 6 then
        ui:write(tx, 1, tabText, colors.black, colors.orange)
        ui:hit(tx, 1, tx + 1, 1, function() cycleLook(-1) end)
        ui:hit(tx + 2, 1, W, 1, function() cycleLook(1) end)
    else
        ui:hit(1, 1, W, 1, function() cycleLook(1) end)
    end

    local text, bg, fg = status()
    ui:fill(1, 2, W, 1, bg)
    ui:center(1, 2, W, text, fg, bg)

    -- the address so far; tap it to take back the last symbol
    local parts = {}
    for i, e in ipairs(seq) do parts[i] = D.label(e.symbol) end
    local addr = #parts > 0 and table.concat(parts, keyset.kind == "letters" and "" or "-") or "_"
    local entry = matchEntry()
    local nextKey, off = guideNext()
    local canAll = guide and not off and nextKey ~= nil and not dome and gate and gate.state ~= "INCOMING" and not gate.connected
    local tail = entry and ("  " .. entry.name) or (guide and ((off and "  off " or "  ") .. guide.name) or "")
    local aw = canAll and 4 or 0
    ui:write(1, 3, pad(fit(" " .. addr .. tail, W - aw), W - aw), (entry or (guide and not off)) and colors.lime or colors.white, colors.black)
    if #seq > 0 then ui:hit(1, 3, W - aw, 3, function() takeBack(#seq) end) end
    if canAll then
        ui:write(W - 3, 3, " ALL", colors.black, colors.lime)
        ui:hit(W - 3, 3, W, 3, pressAll)
    end

    if bookView then
        drawBook(1, 4, W, H - 6)
    else
        -- the keys
        local n = #keyset.symbols
        local labelW = 1
        for _, s in ipairs(keyset.symbols) do labelW = math.max(labelW, #D.label(s)) end
        local kw = labelW + 2
        local perRow = math.max(1, floor((W + 1) / (kw + 1)))
        local nRows = ceil(n / perRow)
        local room = H - 7 -- title, status, address and a gap above; message and buttons below
        local kh = (nRows * 2 + (nRows - 1) <= room) and 2 or 1
        local gap = (kh == 2 and nRows * 3 - 1 <= room) and 1 or 0
        local y0 = 5
        if nRows * (kh + gap) > room + 1 then y0 = 4 end
        for i, s in ipairs(keyset.symbols) do
            local r = floor((i - 1) / perRow)
            local c = (i - 1) % perRow
            local x = 1 + c * (kw + 1)
            local y = y0 + r * (kh + gap)
            local st = keyState(s)
            local waiting = st == "engaging" or (st == "queued" and (keyset.direct or dome ~= nil))
            local on = st == "locked" or (st == "queued" and not waiting) or (waiting and blink)
            local kbg = on and colors.orange or colors.brown
            local kfg = on and colors.purple or colors.pink
            if s == nextKey and not on and not dome then kbg, kfg = colors.lime, colors.purple end
            ui:fill(x, y, kw, kh, kbg)
            ui:center(x, y + floor((kh - 1) / 2), kw, D.label(s), kfg, kbg)
            ui:hit(x, y, x + kw - 1, y + kh - 1, function() pressKey(s) end)
        end
    end

    -- dome, clear, iris
    local by = H - 1
    local domeW = math.max(8, floor(W / 2))
    local domeLabel = (gate and gate.connected) and "CLOSE" or (dome and "DIALING" or "DIAL")
    local domeLit = (gate and gate.connected) or (dome and blink)
    ui:bigButton(1, by, domeW, domeLabel, domeLit and colors.purple or colors.white, domeLit and colors.cyan or colors.magenta, pressDome)
    drawSmallButtons(domeW + 2, by, W - domeW - 1)
    local msg = input ~= "" and ("Typed: " .. input .. "_") or message.text
    ui:write(1, H - 2, pad(msg, W), input ~= "" and colors.yellow or message.color, colors.black)
end

local function draw()
    ui:clearHits()
    if L.mode == "round" then
        drawRound()
        drawPanel()
        -- the keys and the dome
        ui:hit(1, 1, L.cols, L.rows, function(cx, cy)
            local canvas, map = L.canvas, L.map
            -- the class of the pixel in the middle of the touched cell, or of any key in it
            local best
            for dy = 0, 2 do
                for dx = 0, 1 do
                    local c = map[((cy - 1) * 3 + dy) * canvas.w + (cx - 1) * 2 + dx + 1]
                    if c and c >= C_KEY then best = c end
                    if c and (c == C_DOME or c == C_SHINE or c == C_GLINT or c == C_DOME_RIM) and not best then best = C_DOME end
                end
            end
            if not best then return end
            if best == C_DOME then pressDome() else pressKey(keyset.symbols[best - C_KEY]) end
        end)
    else
        drawKeypad()
    end
end

-- the computer's own screen, when the DHD is on a monitor
local function drawNative()
    if not monitor then return end
    native.setBackgroundColor(colors.black)
    native.setTextColor(colors.white)
    native.clear()
    native.setCursorPos(1, 1)
    print("Dial Home Device " .. VERSION .. " on " .. monitorName)
    print("")
    print("Press the symbols on the monitor, then the dome.")
    print("Or type them here: numbers, letters or names,")
    print("then Enter for the dome.")
    print("")
    print("Backspace  take back a typed character")
    print("Delete     clear the address")
    print("Tab        next look")
    print("Ctrl+B     the address book: pick a cartouche")
    print("Ctrl+A     press all of the cartouche's keys")
    print("Ctrl+I     iris     Ctrl+Q  quit")
end

---------------------------------------------------------------------------
-- Keyboard
---------------------------------------------------------------------------

-- presses the key for what has been typed; true if one was found
local function commitInput()
    if input == "" then return false end
    local s = D.match(keyset, input)
    if s == nil then
        setMessage("No key for \"" .. input .. "\"", colors.orange)
        click("error")
    else
        pressKey(s)
    end
    input = ""
    return true
end

local function typed(ch)
    if keyset.kind == "letters" then
        local s = D.match(keyset, ch:upper())
        if s then pressKey(s) else setMessage("No key for \"" .. ch .. "\"", colors.orange) end
        return
    end
    -- names have spaces in them ("Leo Minor"): only a comma or Enter ends one
    if ch == "," or (keyset.kind == "numbers" and (ch == " " or ch == "-")) then
        commitInput()
        return
    end
    input = (input .. ch):sub(1, 20)
    if keyset.kind == "numbers" then
        -- a number goes in as soon as no longer one starts with it
        local candidates, exact = 0, nil
        for _, s in ipairs(keyset.symbols) do
            local t = tostring(s)
            if t:sub(1, #input) == input then candidates = candidates + 1 end
            if t == input then exact = s end
        end
        if candidates == 0 then
            setMessage("No key for \"" .. input .. "\"", colors.orange)
            click("error")
            input = ""
        elseif candidates == 1 and exact then
            input = ""
            pressKey(exact)
        end
    end
end

local function backspace()
    if input ~= "" then
        input = input:sub(1, -2)
    elseif not keyset.direct and #seq > 0 and not dome then
        local e = table.remove(seq)
        setMessage("Took back " .. tostring(e.symbol), colors.lightGray)
    elseif keyset.direct and #seq > 0 then
        setMessage("A locked chevron can't be taken back - CLEAR lets them all go", colors.orange)
    end
end

---------------------------------------------------------------------------
-- Tasks
---------------------------------------------------------------------------

local function gateOpts()
    return {
        stepTimeout = CONFIG.stepTimeout, connectTimeout = CONFIG.connectTimeout, chevronDelay = CONFIG.chevronDelay,
        abort = function() return work.abort end,
    }
end

-- runs the gate jobs one after another, so a slow gate never holds up the screen
local function workerTask()
    while true do
        while #work.queue == 0 do os.pullEvent("dhd_work") end
        local job = table.remove(work.queue, 1)
        local gen = work.gen
        work.busy, work.abort, work.current = true, false, job.kind
        if not gate then
            work.queue = {}
        elseif job.kind == "key" then
            local entry = job.entry
            local n = inSeq(entry.symbol)
            if n then
                entry.state = "engaging"
                os.queueEvent("dhd_redraw")
                local ok, why = D.engage(gate, entry.symbol, n, gateOpts())
                if gen == work.gen then
                    if ok then
                        entry.state = "locked"
                    else
                        -- this key and the ones pressed after it didn't go in
                        local at = inSeq(entry.symbol)
                        if at then for i = #seq, at, -1 do table.remove(seq, i) end end
                        work.queue = {}
                        dome = nil
                        if why ~= "aborted" then
                            setMessage("Chevron " .. n .. ": " .. tostring(why), colors.red)
                            click("error")
                        end
                    end
                end
            end
        elseif job.kind == "origin" then
            local ok, why = D.origin(gate, gateOpts())
            if gen == work.gen then
                dome = nil
                if ok then
                    local entry = book:find(D.address(keyset, symbols()))
                    gate.remote = gate.remote or D.address(keyset, symbols())
                    setMessage("Wormhole open" .. (entry and (" to " .. entry.name) or ""), colors.lightBlue)
                    sendCode()
                elseif why ~= "aborted" then
                    setMessage("Dialing failed: " .. tostring(why), colors.red)
                    click("error")
                end
            end
        elseif job.kind == "dial" then
            local ok, why = gate:dial(job.address, {
                stepTimeout = CONFIG.stepTimeout, connectTimeout = CONFIG.connectTimeout,
                abort = function() return work.abort end,
                onStep = function(i)
                    if gen ~= work.gen then return end
                    for k = 1, math.min(i, #seq) do seq[k].state = "locked" end
                    os.queueEvent("dhd_redraw")
                end,
            })
            if gen == work.gen then
                dome = nil
                if ok then
                    for _, e in ipairs(seq) do e.state = "locked" end
                    local entry = book:find(job.address)
                    setMessage("Wormhole open" .. (entry and (" to " .. entry.name) or ""), colors.lightBlue)
                    sendCode()
                elseif why == "aborted" then
                    setMessage("Dialing stopped", colors.orange)
                else
                    for _, e in ipairs(seq) do e.state = "queued" end
                    setMessage("Dialing failed: " .. tostring(why), colors.red)
                    click("error")
                end
            end
        end
        work.busy, work.current = false, nil
        if gate then gate:poll() end
        os.queueEvent("dhd_redraw")
    end
end

-- gate events, input and radio messages are collected by a task that never calls
-- the gate, so none are lost while another task waits for a slow gate
local gateEvents, inputQueue, radioEvents = {}, {}, {}
local INPUT_EVENTS = {
    key = true, key_up = true, char = true, paste = true, terminate = true,
    mouse_click = true, monitor_touch = true, term_resize = true, monitor_resize = true,
    peripheral = true, peripheral_detach = true,
}

local function listenerTask()
    while true do
        local e = table.pack(os.pullEventRaw())
        if Gate.EVENTS[e[1]] then
            gateEvents[#gateEvents + 1] = e
            os.queueEvent("dhd_gate_event")
        elseif e[1] == "modem_message" then
            radioEvents[#radioEvents + 1] = e
            os.queueEvent("dhd_radio")
        elseif INPUT_EVENTS[e[1]] then
            inputQueue[#inputQueue + 1] = e
            os.queueEvent("dhd_input")
        end
    end
end

local function onGateEvent(info)
    if not info then return end
    local ty = info.type
    if ty == "incoming" or ty == "dialin" or (ty == "chevron" and info.incoming) then
        if busy() or dome then dropJobs() end
        if ty ~= "chevron" then
            setMessage("Incoming wormhole" .. (info.address and (" from " .. book:describe(info.address)) or ""), colors.red)
        end
    elseif ty == "outgoing" then
        if not busy() and not dome then
            -- dialed from somewhere else: the DHD block, another computer
            local who = info.address and book:describe(info.address)
            setMessage("Wormhole open" .. (who and (" to " .. who) or ""), colors.lightBlue)
            sendCode()
        end
    elseif ty == "closed" or ty == "reset" or ty == "idle" then
        if relay then relay:closed() end
        if not busy() and not dome then
            if info.error and info.reason then setMessage("Gate reset: " .. tostring(info.reason), colors.red)
            elseif ty == "closed" then setMessage("Wormhole closed" .. (info.reason and (": " .. info.reason) or ""), colors.lightGray) end
        end
    elseif ty == "traveler" then
        local name = info.name and tostring(info.name) or "Traveller"
        setMessage(name .. (info.direction == "out" and " stepped through the gate" or " came through the gate"), colors.lightBlue)
    elseif ty == "message" then
        local kind, value = IDC.parse(info.text)
        if kind == "accepted" then
            local forGdo = relay and relay:answer(kind, value)
            setMessage((forGdo and "GDO code accepted" or "Iris code accepted") .. (value and (" as " .. value) or "") .. " - the way is open", colors.lime)
        elseif kind == "rejected" then
            local forGdo = relay and relay:answer(kind, value)
            setMessage((forGdo and "GDO code rejected" or "Iris code rejected") .. " - their iris stays closed", colors.red)
        elseif kind == "code" then
            setMessage("Iris code " .. value .. " came through (the Gate Room checks codes)", colors.yellow)
        else
            setMessage("Message: " .. tostring(info.text), colors.yellow)
        end
    end
end

local function tickTask()
    while true do
        sleep(0.4)
        os.queueEvent("dhd_tick")
    end
end

local function needsBlink()
    if dome or (gate and gate.state == "INCOMING") then return true end
    for _, e in ipairs(seq) do
        if e.state == "engaging" or (e.state == "queued" and (keyset.direct or dome)) then return true end
    end
    return false
end

local function uiTask()
    local held = {}
    local nextPoll = os.clock() + CONFIG.pollInterval
    draw()
    drawNative()
    while running do
        local e
        if #inputQueue > 0 then
            e = table.remove(inputQueue, 1)
        else
            e = table.pack(os.pullEventRaw())
            if INPUT_EVENTS[e[1]] then e = { n = 1, "dhd_input" } end
        end
        local name = e[1]
        local redraw = true
        local polled = false
        if os.clock() >= nextPoll then
            if gate then gate:poll() end
            nextPoll = os.clock() + CONFIG.pollInterval
            polled = true
        end
        if name == "terminate" then
            running = false
        elseif name == "dhd_tick" then
            blink = not blink
            redraw = polled or needsBlink() or (gate and gate.state == "OPEN")
        elseif name == "timer" or name == "dhd_gate_event" or name == "dhd_radio" or name == "dhd_input" then
            redraw = polled
        elseif name == "peripheral" then
            local t = peripheral.getType(e[2])
            if not gate and Gate.isInterfaceType(t) then
                gate = Gate.find(CONFIG.interfaceName)
                if gate and (gate.mod == "lanteacraft" or gate.mod == "lanteacraft17") then A.plainLetters = true end
                keyset = D.keys(gate)
                if not CONFIG.look and not settings.get("dhd.look") then style = lookFor(gate) end
                Styles.apply(target, style)
                resetKeys()
                layout()
                setMessage(gate and "Stargate interface connected" or "", colors.lime)
            elseif t == "modem" then
                startRelay()
            elseif t == "speaker" then
                speaker = peripheral.find("speaker")
            end
        elseif name == "peripheral_detach" then
            if gate and e[2] == gate.name then
                dropJobs()
                gate = nil
                keyset = D.keys(nil)
                resetKeys()
                layout()
                setMessage("Stargate interface disconnected", colors.red)
            end
            if relay and relay:detached(e[2]) then relay = nil end
        elseif name == "monitor_touch" then
            if e[2] == monitorName then ui:click(e[3], e[4], 1) else redraw = false end
        elseif name == "mouse_click" then
            if not monitor then ui:click(e[3], e[4], e[2]) else redraw = false end
        elseif name == "key" then
            held[e[2]] = true
            local ctrl = held[keys.leftCtrl] or held[keys.rightCtrl]
            local k = e[2]
            if ctrl and k == keys.q then running = false
            elseif ctrl and k == keys.i then toggleIris()
            elseif ctrl and k == keys.b then toggleBook()
            elseif ctrl and k == keys.a then pressAll()
            elseif ctrl then -- other shortcuts are not ours
            elseif k == keys.enter or k == keys.numPadEnter then
                if not commitInput() then pressDome() end
            elseif k == keys.backspace then backspace()
            elseif k == keys.delete then clearKeys()
            elseif k == keys.tab then cycleLook(1)
            else redraw = false
            end
        elseif name == "key_up" then
            held[e[2]] = nil
            redraw = false
        elseif name == "char" then
            if not (held[keys.leftCtrl] or held[keys.rightCtrl]) then typed(e[2]) else redraw = false end
        elseif name == "paste" then
            for ch in tostring(e[2]):gmatch(".") do typed(ch) end
            commitInput()
        elseif name == "monitor_resize" or name == "term_resize" then
            layout()
            drawNative()
        elseif name ~= "dhd_redraw" then
            redraw = false
        end
        if #gateEvents > 0 then
            local pending = gateEvents
            gateEvents = {}
            for _, ge in ipairs(pending) do
                if gate then onGateEvent(gate:event(ge)) end
            end
            redraw = true
        end
        if #radioEvents > 0 then
            local pending = radioEvents
            radioEvents = {}
            for _, re in ipairs(pending) do
                local r = relay and relay:event(re)
                if r and r.kind == "sent" then
                    setMessage("A traveller's GDO sent code " .. r.code .. " through the gate", colors.lightBlue)
                    redraw = true
                elseif r then
                    setMessage("A traveller's GDO code " .. tostring(r.code) .. " was not sent: " .. r.why, colors.orange)
                    redraw = true
                end
            end
        end
        followGate()
        if running and redraw then draw() end
    end
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

Styles.apply(target, style)
layout()
startRelay()
if book.notice then
    setMessage(book.notice, colors.yellow)
elseif not gate then
    setMessage("No stargate interface found", colors.red)
elseif keyset.why then
    setMessage(keyset.why, colors.orange)
else
    setMessage("Press the symbols of an address, then the dome", colors.lightGray)
end
if gate then gate:poll() lastState = gate.state end
followGate()

local ok, err = pcall(parallel.waitForAny, uiTask, workerTask, listenerTask, tickTask)

if relay then relay:close() end
Styles.reset(target)
target.setBackgroundColor(colors.black)
target.setTextColor(colors.white)
target.clear()
target.setCursorPos(1, 1)
if monitor then
    native.setBackgroundColor(colors.black)
    native.clear()
    native.setCursorPos(1, 1)
end
if not ok and err ~= "Terminated" then printError(err) else print("Dial Home Device closed.") end
