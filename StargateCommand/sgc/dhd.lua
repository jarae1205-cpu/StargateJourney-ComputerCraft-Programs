--
-- sgc.dhd - the keys of a dial home device, and pressing them on a gate
--
-- A real DHD locks a chevron for every key you press, and the big dome in the
-- middle engages the point of origin and opens the wormhole. Gates that a
-- computer can dial one symbol at a time work the same way here ("direct"):
--
--   Stargate Journey and Chevron Seven   engageSymbol on a crystal interface; on a
--                                        basic interface the ring turns to the
--                                        symbol and the top chevron opens and closes
--   Lantea: Stargates                    encodeSymbol (Milky Way gates)
--
-- The others take a whole address at once ("queued"): the keys build up the
-- address, and the dome dials it with sgc.gate's dial().
--
--   SGCraft                              36 letters and digits, 7 or 9 of them
--   LanteaCraft                          A-Z, 0-9, - and +, 7 to 9 of them (7 or 9 on 1.7.10)
--   Just Stargate Mod (1.20.1)           symbol names, 6 to 8 of them
--
-- local keyset = D.keys(gate)     what the DHD's keys are for this gate, see below
-- D.engage(gate, symbol, n, opts)  blocking: lock one symbol as chevron n (direct gates)
-- D.origin(gate, opts)             blocking: engage the point of origin (direct gates)
--

local A = require("sgc.address")

local D = {}

local floor = math.floor

-- Just Stargate Mod's symbol names, as JSG 5.1.2.0 spells them (its SymbolMilkyWayEnum,
-- SymbolPegasusEnum and SymbolUniverseEnum). JSG looks names up without regard to case.
-- The points of origin (Point of Origin, Subido, Glyph 17) are the dome, not keys.
D.JSG_MILKY_WAY = {
    "Andromeda", "Aquarius", "Aries", "Auriga", "Bootes", "Cancer", "Canis Minor", "Capricornus",
    "Centaurus", "Cetus", "Corona Australis", "Crater", "Equuleus", "Eridanus", "Gemini", "Hydra",
    "Leo", "Leo Minor", "Libra", "Lynx", "Microscopium", "Monoceros", "Norma", "Orion", "Pegasus",
    "Perseus", "Pisces", "Piscis Austrinus", "Sagittarius", "Scorpius", "Sculptor", "Scutum",
    "Serpens Caput", "Sextans", "Taurus", "Triangulum", "Virgo",
}
-- JSG also has two placeholder symbols, Unknow1 and Unknow2, that addresses can't use
D.JSG_PEGASUS = {
    "Aaxel", "Abrin", "Acjesis", "Aldeni", "Alura", "Amiwill", "Arami", "Avoniv", "Baselai",
    "Bydo", "Ca Po", "Danami", "Dawnre", "Ecrumig", "Elenami", "Gilltin", "Hacemill", "Hamlinto",
    "Illume", "Laylox", "Lenchan", "Olavii", "Once El", "Poco Re", "Ramnon", "Recktic", "Robandus",
    "Roehi", "Salma", "Sandovi", "Setas", "Sibbron", "Tahnan", "Zamilloz", "Zeo",
}
-- Universe symbols are "Glyph 1" to "Glyph 36" (JSG also takes "G1" to "G36" when dialing)
D.JSG_ORIGIN = { milky_way = "Point of Origin", pegasus = "Subido", universe = "Glyph 17", tollan = "Point of Origin" }

D.SGCRAFT = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
D.LANTEACRAFT = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-+"

-- a short label for a key: "26", "K", "Crat", "LeoM", "G5"
function D.label(symbol)
    if type(symbol) ~= "string" or #symbol <= 3 then return tostring(symbol) end
    local glyph = symbol:match("^[Gg]lyph%s+(%d+)$")
    if glyph then return "G" .. glyph end
    local first, second = symbol:match("^(%S+)%s+(%S+)")
    if first then return first:sub(1, 3) .. second:sub(1, 1):upper() end
    return symbol:sub(1, 4)
end

local function letters(s)
    local out = {}
    for c in s:gmatch(".") do out[#out + 1] = c end
    return out
end

-- true if a Stargate Journey style interface can lock one symbol at a time
local function journeyDirect(g)
    if g:has("engageSymbol") then return true end
    local openName = g:has("openChevron") or g:has("raiseChevron")
    local closeName = g:has("closeChevron") or g:has("lowerChevron")
    return g:has("rotateClockwise") and g:has("isCurrentSymbol") and openName and closeName and true or false
end

-- What the keys are for this gate:
--   { symbols = { ... }       the keys, in order (the point of origin is the dome, not a key)
--     origin = 0 | "Point of Origin" | nil
--     kind = "numbers" | "letters" | "names"
--     direct = true            every key locks its chevron as it is pressed
--     lengths = { [6] = true, ... }   how many symbols an address can have
--     max = 8
--     why = "..."              set when this gate can't be dialed from a DHD
--   }
function D.keys(g)
    local k = { symbols = {}, kind = "numbers", direct = false, lengths = {}, max = 8 }
    local function range(n) for i = 1, n - 1 do k.symbols[#k.symbols + 1] = i end end
    if not g then
        range(39)
        k.origin, k.lengths = 0, { [6] = true, [7] = true, [8] = true }
        k.why = "No stargate interface"
        return k
    end
    local mod = g.mod
    if mod == "sgjourney" and g.ptype == "chevron7_stargate" then
        -- Chevron Seven's ring: addresses are always six symbols and the point of origin
        range(g.symbolCount or 39)
        k.origin, k.lengths, k.max, k.direct = 0, { [6] = true }, 6, true
        if tostring(g:call("getStargateType") or ""):find("network", 1, true) then
            -- its Stargate Network gate numbers its letters 0-35 here, so 0 is A, not the point of origin
            k.direct = false
            k.why = "Connect this Stargate Network gate through its SG Computer Interface to dial its letters"
        end
    elseif mod == "sgjourney" then
        range(g.symbolCount or 39)
        k.origin, k.lengths = 0, { [6] = true, [7] = true, [8] = true }
        k.direct = journeyDirect(g)
        if not k.direct then k.why = "This interface can't dial a " .. tostring(g.typeName) .. " gate (use a crystal interface)" end
    elseif mod == "lantea" then
        range(g.symbolCount or 39)
        k.origin, k.lengths, k.max = 0, { [6] = true, [7] = true }, 7
        k.direct = g.canDial ~= false
        if not k.direct then k.why = "Lantea Pegasus gates can't be dialed by a computer" end
    elseif mod == "sgcraft" then
        k.symbols, k.kind = letters(D.SGCRAFT), "letters"
        k.lengths, k.max = { [7] = true, [9] = true }, 9
    elseif mod == "lanteacraft" or mod == "lanteacraft17" then
        k.symbols, k.kind = letters(D.LANTEACRAFT), "letters"
        k.lengths, k.max = { [7] = true, [8] = true, [9] = true }, 9
        -- the 1.7.10 releases: 7 glyphs within a dimension, 9 to reach another
        if mod == "lanteacraft17" then k.lengths[8] = nil end
    elseif mod == "jsg" or mod == "jsg112" then
        k.kind, k.lengths = "names", { [6] = true, [7] = true, [8] = true }
        k.origin = D.JSG_ORIGIN[g.typeId] or g.originSymbol
        if g.typeId == "universe" then
            for i = 1, 36 do if i ~= 17 then k.symbols[#k.symbols + 1] = "Glyph " .. i end end
        elseif g.typeId == "pegasus" then
            for i, s in ipairs(D.JSG_PEGASUS) do k.symbols[i] = s end
        else
            for i, s in ipairs(D.JSG_MILKY_WAY) do k.symbols[i] = s end
        end
    else
        k.why = "This gate can't be dialed from a DHD"
    end
    return k
end

-- a readable list of the address lengths: "6, 7 or 8"
function D.lengthText(k)
    local list = {}
    for n = 1, 12 do if k.lengths[n] then list[#list + 1] = tostring(n) end end
    if #list <= 1 then return list[1] or "?" end
    return table.concat(list, ", ", 1, #list - 1) .. " or " .. list[#list]
end

-- the key for something typed on the keyboard: "26", "k", "crat", "leo m"
function D.match(k, text)
    text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil end
    if k.kind == "numbers" then
        local n = tonumber(text)
        for _, s in ipairs(k.symbols) do if s == n then return s end end
        return nil
    end
    local low = text:lower()
    local found
    for _, s in ipairs(k.symbols) do
        local name = tostring(s):lower()
        if name == low or D.label(s):lower() == low then return s end
        if name:sub(1, #low) == low then
            if found then return nil end -- more than one name starts like that
            found = s
        end
    end
    return found
end

-- true if the symbol is a point of origin (0, "Point of Origin", "Subido", "Glyph 17", ...)
function D.isOrigin(k, symbol)
    if symbol == nil then return false end
    if symbol == k.origin or symbol == 0 then return true end
    if type(symbol) ~= "string" then return false end
    return A.isOriginName(symbol) or (type(k.origin) == "string" and symbol:lower() == k.origin:lower())
end

-- true if the symbol is one of the keys
function D.isKey(k, symbol)
    for _, s in ipairs(k.symbols) do
        if s == symbol or (type(s) == "string" and type(symbol) == "string" and s:lower() == symbol:lower()) then return true end
    end
    return false
end

-- the address a list of pressed keys makes, in the form sgc.address and sgc.gate use
function D.address(k, pressed)
    if k.kind == "letters" then return table.concat(pressed) end
    local out = {}
    for i, s in ipairs(pressed) do out[i] = s end
    return out
end

---------------------------------------------------------------------------
-- locking one symbol (direct gates; blocking, run it in its own coroutine)
---------------------------------------------------------------------------

local function G() return require("sgc.gate") end

local function now() return os.clock() end

local function journeyEngage(g, symbol, n, opts)
    local Gate = G()
    local stepTimeout = opts.stepTimeout or 60
    if g:has("engageSymbol") then
        g:checkFeedback(g:call("engageSymbol", symbol))
    else
        local openName = g:has("openChevron") and "openChevron" or "raiseChevron"
        local closeName = g:has("closeChevron") and "closeChevron" or "lowerChevron"
        if not g:call("isCurrentSymbol", symbol) then
            -- turn the ring the other way for every other chevron, as the gate does
            if n % 2 == 0 then g:call("rotateClockwise", symbol) else g:call("rotateAntiClockwise", symbol) end
            if not Gate.waitUntil(opts, function() return g:call("isCurrentSymbol", symbol) end, stepTimeout) then
                g:call("endRotation")
                Gate.fail("The ring did not reach symbol " .. tostring(symbol))
            end
        end
        local delay = opts.chevronDelay or 0.4
        Gate.pause(opts, delay)
        g:checkFeedback(g:call(openName), { -26, -34 })
        Gate.pause(opts, delay)
        g:checkFeedback(g:call(closeName), { -2, -27, -35 })
    end
    if symbol == 0 then return end
    if not Gate.waitUntil(opts, function()
        g.chevrons = g:call("getChevronsEngaged") or 0
        return g.chevrons >= n
    end, g:has("engageSymbol") and stepTimeout or 5) then
        Gate.fail("Chevron " .. n .. " did not lock")
    end
end

local function lanteaEngage(g, symbol, n, opts)
    local Gate = G()
    local stepTimeout = opts.stepTimeout or 60
    local function failed()
        if g.lastFailure then Gate.fail(g.lastFailure) end
    end
    if not Gate.waitUntil(opts, function()
        failed()
        return not g:call("isRingTurning") and (g:call("getNextChevron") or 0) > 0
    end, stepTimeout) then
        Gate.fail("The gate is not ready for chevron " .. n)
    end
    -- Lantea refuses the next symbol while a chevron is still locking: wait and try again
    local ok, err
    local deadline = now() + stepTimeout
    while true do
        ok, err = g:try("encodeSymbol", symbol)
        if ok or not tostring(err):find("still locking", 1, true) or now() > deadline then break end
        Gate.pause(opts, 0.25)
    end
    if not ok then Gate.fail((tostring(err):gsub("^.-:%d+: ", ""))) end
    if symbol == 0 then return end
    if not Gate.waitUntil(opts, function()
        failed()
        return (g:call("getChevronsLocked") or 0) >= n
    end, stepTimeout) then
        Gate.fail("Chevron " .. n .. " did not lock")
    end
end

-- runs fn(g, ...) the way sgc.gate's dial() does: true, or false + why ("aborted" when stopped)
local function run(g, fn, ...)
    local Gate = G()
    g.dialing = true
    g.outgoing, g.incomingChevrons = true, false
    local ok, err = pcall(fn, g, ...)
    g.dialing = false
    if ok then return true end
    if err == "Terminated" then error(err, 0) end
    if type(err) == "table" and err[1] ~= nil and err[2] == nil then
        -- sgc.gate's abort marker
        return false, "aborted"
    end
    return false, type(err) == "table" and tostring(err[2]) or tostring(err)
end

local function engageFn(g)
    if g.mod == "lantea" then return lanteaEngage end
    return journeyEngage
end

-- locks one symbol as chevron n. opts as for sgc.gate's dial (abort, stepTimeout, chevronDelay)
function D.engage(g, symbol, n, opts)
    if n == 1 then g.lastFailure = nil end
    return run(g, engageFn(g), symbol, n, opts or {})
end

-- engages the point of origin and waits for the wormhole
function D.origin(g, opts)
    opts = opts or {}
    local Gate = G()
    return run(g, function()
        local n = (g.chevrons or 0) + 1
        engageFn(g)(g, 0, n, opts)
        local connected = function()
            if g.mod == "lantea" then
                if g.lastFailure then Gate.fail(g.lastFailure) end
                local st = g:call("getState")
                if st == "idle" or st == "fault" then Gate.fail("No connection was established") end
                return st == "open"
            end
            return g:call("isStargateConnected") == true
        end
        if not Gate.waitUntil(opts, connected, opts.connectTimeout or 10) then
            local code = g:call("getRecentFeedback")
            Gate.fail(type(code) == "number" and code < 0 and g:feedbackText(code) or "No connection was established")
        end
        g.outgoing = true
    end)
end

return D
