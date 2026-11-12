--
--   Personal Dialer
--   An address book dialer for the Stargate Journey mod (CC: Tweaked)
--
--   Usage:
--     dialer            run on the computer's own screen
--     dialer monitor    draw on an attached advanced monitor (touch to use,
--                       type on the computer to search)
--
--   Works with the basic, crystal and advanced crystal interface and with
--   every gate type (Milky Way, Pegasus, Universe, Tollan, Classic), and with
--   Greg's SGCraft (Minecraft 1.7.10 - 1.12.2) through its computer interface.
--   An advanced computer is recommended (mouse + colour).
--

local VERSION = "1.1"

--
-- CONFIGURATION
--
local CONFIG = {
    -- where the address book and settings are stored
    dataFile = "dialer_addresses.db",

    -- peripheral name of the interface (e.g. "left" or "advanced_crystal_interface_0")
    -- nil = use the first interface found
    interfaceName = nil,

    -- pause after each symbol when engaging symbols directly (seconds, ignored in fast mode)
    symbolDelay = 0.5,
    -- pause between ring stop / chevron open / chevron close on a Milky Way gate
    chevronDelay = 0.4,
    -- give up on a single symbol after this many seconds (Milky Way ring rotation can be slow)
    stepTimeout = 60,
    -- how long to wait for the wormhole after the point of origin was encoded
    connectTimeout = 10,

    -- auto-close: close an outgoing wormhole this many seconds after someone steps through
    autoCloseDelay = 3,
    -- auto-close: close an outgoing wormhole nobody used after this many seconds
    autoCloseIdle = 30,

    -- how often the gate status is re-read, in seconds (events can be missed)
    pollInterval = 1,

    -- text scale used in monitor mode
    monitorScale = 0.5,
}
--
-- END OF CONFIGURATION
--

local args = { ... }

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function fit(s, width)
    s = tostring(s or "")
    if width <= 0 then return "" end
    if #s <= width then return s end
    if width <= 2 then return s:sub(1, width) end
    return s:sub(1, width - 2) .. ".."
end

local function commas(n)
    if type(n) ~= "number" then return "?" end
    local s = tostring(math.floor(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""):gsub("^%-,", "-"))
end

local function wrap(text, width)
    local lines = {}
    for para in (tostring(text) .. "\n"):gmatch("(.-)\n") do
        local line = ""
        for word in para:gmatch("%S+") do
            if #line == 0 then
                line = word
            elseif #line + 1 + #word <= width then
                line = line .. " " .. word
            else
                lines[#lines + 1] = line
                line = word
            end
            while #line > width do
                lines[#lines + 1] = line:sub(1, width)
                line = line:sub(width + 1)
            end
        end
        lines[#lines + 1] = line
    end
    return lines
end

-- Stargate Journey addresses are tables of numbers, SGCraft addresses are
-- strings of 7 or 9 letters/digits ("WLDQDQBMT"), planned entries have none
local function formatAddress(address)
    if type(address) == "string" and #address > 0 then
        return address:sub(1, 4) .. "-" .. address:sub(5, 7) .. (#address > 7 and ("-" .. address:sub(8)) or "")
    end
    if type(address) ~= "table" or #address == 0 then return "-" end
    return "-" .. table.concat(address, "-") .. "-"
end

-- copies an address and drops the point of origin (0) from the end
local function stripOrigin(address)
    if type(address) == "string" then return address end
    local out = {}
    if type(address) ~= "table" then return out end
    for i, s in ipairs(address) do out[i] = s end
    if out[#out] == 0 then out[#out] = nil end
    return out
end

local function sameAddress(a, b)
    if type(a) == "string" or type(b) == "string" then
        return type(a) == "string" and a ~= "" and a == b
    end
    a, b = stripOrigin(a), stripOrigin(b)
    if #a ~= #b or #a == 0 then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

-- symbols shown on the chevron bar: the point of origin is added for Stargate Journey
local function chevronSymbols(address)
    local out = {}
    if type(address) == "string" then
        for c in address:gmatch(".") do out[#out + 1] = c end
        return out
    end
    out = stripOrigin(address)
    out[#out + 1] = 0
    return out
end

-- reads an address from an interface result or event (table or SGCraft string)
local function toAddress(v)
    if type(v) == "string" then
        v = v:upper():gsub("[^A-Z0-9]", "")
        return #v > 0 and v or nil
    end
    if type(v) ~= "table" then return nil end
    local out = {}
    for _, s in ipairs(v) do
        if type(s) == "number" then out[#out + 1] = s end
    end
    out = stripOrigin(out)
    return #out > 0 and out or nil
end

-- accepts "-26-6-14-31-11-29-", "26 6 14 31 11 29", "26,6,14,..."
-- and SGCraft addresses like "WLDQ-DQB-MT"
local function parseAddress(text)
    if tostring(text or ""):find("%a") then
        local s = tostring(text):upper():gsub("[^A-Z0-9]", "")
        if #s ~= 7 and #s ~= 9 then return nil, "SGCraft addresses have 7 or 9 letters/digits" end
        return s
    end
    local address = {}
    for num in tostring(text or ""):gmatch("%d+") do
        address[#address + 1] = tonumber(num)
    end
    if address[#address] == 0 then
        address[#address] = nil -- point of origin is added when dialing
    end
    if #address < 6 or #address > 8 then
        return nil, "Address needs 6 to 8 symbols (without the point of origin)"
    end
    local seen = {}
    for _, s in ipairs(address) do
        if s < 1 or s > 38 then return nil, "Symbol " .. s .. " is out of range (1-38)" end
        if seen[s] then return nil, "Symbol " .. s .. " is used twice" end
        seen[s] = true
    end
    return address
end

---------------------------------------------------------------------------
-- Themes and gate types
---------------------------------------------------------------------------

local THEMES = {
    milky_way = { name = "Milky Way",     header = colors.gray,  title = colors.orange,    address = colors.orange,    lit = colors.orange,    master = colors.red,       button = colors.orange },
    pegasus   = { name = "Pegasus",       header = colors.blue,  title = colors.lightBlue, address = colors.lightBlue, lit = colors.lightBlue, master = colors.cyan,      button = colors.lightBlue },
    universe  = { name = "Universe",      header = colors.gray,  title = colors.white,     address = colors.lightGray, lit = colors.white,     master = colors.white,     button = colors.white },
    tollan    = { name = "Tollan",        header = colors.cyan,  title = colors.white,     address = colors.cyan,      lit = colors.lightBlue, master = colors.white,     button = colors.cyan },
    classic   = { name = "Classic",       header = colors.brown, title = colors.yellow,    address = colors.yellow,    lit = colors.orange,    master = colors.yellow,    button = colors.yellow },
    sg1       = { name = "SG-1",          header = colors.gray,  title = colors.red,       address = colors.orange,    lit = colors.red,       master = colors.orange,    button = colors.red },
    movie     = { name = "Movie",         header = colors.brown, title = colors.orange,    address = colors.yellow,    lit = colors.orange,    master = colors.yellow,    button = colors.orange },
    atlantis  = { name = "Atlantis",      header = colors.blue,  title = colors.cyan,      address = colors.cyan,      lit = colors.cyan,      master = colors.lightBlue, button = colors.cyan },
    infinity  = { name = "Infinity",      header = colors.gray,  title = colors.lime,      address = colors.lime,      lit = colors.lime,      master = colors.yellow,    button = colors.lime },
    sgcraft   = { name = "SGCraft",       header = colors.gray,  title = colors.orange,    address = colors.orange,    lit = colors.orange,    master = colors.red,       button = colors.orange },
    -- multi-coloured chevrons: amber, red and purple pairs with a blue master chevron
    hybrid    = { name = "Legacy Hybrid", header = colors.blue,  title = colors.lightBlue, address = colors.lightBlue, lit = colors.orange,    master = colors.lightBlue, button = colors.lightBlue,
                  palette = { colors.orange, colors.red, colors.purple, colors.purple, colors.red, colors.orange, colors.white, colors.white } },
}
local THEME_ORDER = { "auto", "milky_way", "sg1", "movie", "pegasus", "atlantis", "universe", "tollan", "classic", "infinity", "hybrid", "sgcraft" }

local GATE_TYPES = {
    { match = "milky_way", name = "Milky Way", theme = "milky_way" },
    { match = "pegasus",   name = "Pegasus",   theme = "pegasus" },
    { match = "universe",  name = "Universe",  theme = "universe" },
    { match = "tollan",    name = "Tollan",    theme = "tollan" },
    { match = "classic",   name = "Classic",   theme = "classic" },
    { match = "sgcraft",   name = "SGCraft",   theme = "sgcraft" },
}

-- gate variants (Stargate Journey "stargate variant crystal", resource packs) that have their own theme
local VARIANT_THEMES = {
    { "sg%-?1", "sg1" }, { "promo", "sg1" }, { "movie", "movie" }, { "atlantis", "atlantis" }, { "lantea", "atlantis" },
    { "infinity", "infinity" }, { "hybrid", "hybrid" }, { "legacy", "hybrid" }, { "destiny", "universe" },
}

local STATE_STYLE = {
    IDLE     = { label = "IDLE",     fg = colors.white, bg = colors.green },
    DIALING  = { label = "DIALING",  fg = colors.black, bg = colors.orange },
    OPEN     = { label = "OPEN",     fg = colors.black, bg = colors.lightBlue },
    INCOMING = { label = "INCOMING", fg = colors.white, bg = colors.red },
    OFFLINE  = { label = "NO GATE",  fg = colors.white, bg = colors.gray },
}

-- Stargate Journey feedback codes (used when the interface gives no description)
local FEEDBACK = {
    [0] = "No feedback", [-1] = "Unknown error",
    [1] = "Symbol encoded", [-2] = "Symbol already in address", [-3] = "Symbol out of bounds",
    [2] = "Connected (same system)", [3] = "Connected (interstellar)", [4] = "Connected (intergalactic)",
    [-4] = "Incomplete address", [-5] = "Invalid address", [-6] = "Not enough power",
    [-7] = "This gate is obstructed", [-8] = "Target gate is obstructed", [-9] = "A gate can't dial itself",
    [-10] = "Target is in the same system", [-11] = "Already connected", [-12] = "No galaxy",
    [-13] = "No dimensions", [-14] = "No stargates", [-15] = "Target restricted",
    [7] = "Disconnected", [8] = "Closed by the point of origin", [9] = "Closed by the network",
    [10] = "Closed by autoclose", [-17] = "Ran out of power", [-20] = "Connection forming",
    [-21] = "Stargate destroyed", [-22] = "Could not reach the target gate",
    [-23] = "Interrupted by an incoming connection",
    [11] = "Chevron opened", [12] = "Rotating", [-24] = "Rotation blocked", [-25] = "Not rotating",
    [13] = "Rotation stopped", [-26] = "Chevron already open", [-27] = "Chevron already closed",
    [-28] = "Chevron not open", [-29] = "Cannot encode the point of origin",
}

---------------------------------------------------------------------------
-- Address book (persistence)
---------------------------------------------------------------------------

local DEFAULT_ENTRIES = {
    { name = "Abydos", address = { 26, 6, 14, 31, 11, 29 },    note = "Milky Way" },
    { name = "Chulak", address = { 8, 1, 22, 14, 36, 19 },     note = "Milky Way" },
    { name = "Lantea", address = { 18, 20, 1, 15, 14, 7, 19 }, note = "Pegasus" },
}

local db = {
    entries = {},
    settings = { autoClose = true, theme = "auto", fastDial = false },
}
local loadNotice

local function saveBook()
    local f = fs.open(CONFIG.dataFile, "w")
    if not f then return false end
    f.write(textutils.serialize(db))
    f.close()
    return true
end

-- entries without an address are "planned" gates (from the Network Hub)
local function cleanEntry(e)
    if type(e) ~= "table" then return nil end
    local address = toAddress(e.address)
    local name = trim(e.name)
    if not address and name == "" then return nil end
    return {
        name = name ~= "" and name or formatAddress(address),
        address = address,
        note = trim(e.note),
        -- kept for the Network Hub and the Gate Room
        group = type(e.group) == "string" and e.group ~= "" and e.group or nil,
        color = type(e.color) == "string" and e.color or nil,
        last = (e.last == "ok" or e.last == "fail") and e.last or nil,
    }
end

local function loadBook()
    if fs.exists(CONFIG.dataFile) then
        local f = fs.open(CONFIG.dataFile, "r")
        local data = f and textutils.unserialize(f.readAll())
        if f then f.close() end
        if type(data) == "table" then
            for _, e in ipairs(type(data.entries) == "table" and data.entries or {}) do
                local clean = cleanEntry(e)
                if clean then db.entries[#db.entries + 1] = clean end
            end
            if type(data.settings) == "table" then
                for k, v in pairs(data.settings) do db.settings[k] = v end
            end
            return
        end
        -- unreadable file: keep a copy instead of overwriting the user's addresses
        local backup = CONFIG.dataFile .. ".bak"
        if fs.exists(backup) then fs.delete(backup) end
        fs.copy(CONFIG.dataFile, backup)
        loadNotice = "Address book was unreadable, saved a copy as " .. backup
    end

    -- first run: import the Stargate Monitor cartouche if it is next to us
    if fs.exists("1_cartouche.lua") then
        local ok, list = pcall(dofile, "1_cartouche.lua")
        if ok and type(list) == "table" then
            for _, e in ipairs(list) do
                local clean = cleanEntry(e)
                if clean and type(clean.address) == "table" and #clean.address >= 6 then db.entries[#db.entries + 1] = clean end
            end
            loadNotice = "Imported " .. #db.entries .. " addresses from 1_cartouche.lua"
        end
    end
    if #db.entries == 0 then
        for _, e in ipairs(DEFAULT_ENTRIES) do db.entries[#db.entries + 1] = cleanEntry(e) end
    end
    saveBook()
end

local function findByAddress(address)
    if not address then return nil end
    for _, e in ipairs(db.entries) do
        if e.address and sameAddress(e.address, address) then return e end
    end
end

---------------------------------------------------------------------------
-- Stargate interface
---------------------------------------------------------------------------

local iface, ifaceName, ifaceType

-- Greg's SGCraft "stargate" interface, wrapped so it answers the same calls
-- as a Stargate Journey interface
local SGCRAFT_IRIS = { Open = 0, Opening = 40, Closing = 60, Closed = 100 }
-- SGCraft 2.x reports errors as message keys
local SGCRAFT_ERRORS = {
    unknownAddress = "No stargate at that address", selfBusy = "The gate is busy", selfIncomplete = "The gate isn't complete",
    targetBusy = "The gate at that address is busy", selfOutOfRange = "This gate is out of stargate range",
    targetOutOfRange = "The destination is out of range", diallingItself = "A gate can't dial itself",
    selfLackChevrons = "This gate needs more chevrons", targetLackChevrons = "The destination gate lacks chevrons",
    insufficientEnergy = "Not enough energy to dial", malformedAddress = "Malformed address",
    dimensionTooFar = "That dimension is out of reach", zpmNotFound = "That address needs a ZPM",
    zpmLowPower = "The ZPM lacks the power", incomingConnection = "Interrupted by an incoming connection",
    irisAtDestination = "Destination blocked by its iris", cannotDialToThisGate = "That gate can't be dialed",
    cannotDialFromThisGate = "This gate can't dial out",
}
local function sgcraftError(err)
    local msg = tostring(err):gsub("^.-:%d+: ", "")
    if SGCRAFT_ERRORS[msg] then return SGCRAFT_ERRORS[msg] end
    if msg:match("^%l%w+$") then
        msg = msg:gsub("(%u)", function(c) return " " .. c:lower() end)
        return (msg:gsub("^%l", string.upper))
    end
    return msg
end
local function sgcraftInterface(p)
    local function state()
        local ok, s, chevrons, direction = pcall(p.stargateState)
        if ok then return s, tonumber(chevrons) or 0, direction end
        return "Offline", 0, ""
    end
    local w = { sgcraft = true }
    function w.getStargateType() return "sgcraft:stargate" end
    function w.getChevronsEngaged() local _, c = state() return c end
    function w.isStargateConnected() return (state()) == "Connected" end
    function w.isStargateDialingOut()
        local _, _, d = state()
        if d == "Outgoing" then return true elseif d == "Incoming" then return false end
        return nil
    end
    function w.disconnectStargate() return p.disconnect() end
    function w.getLocalAddress() return p.localAddress() end
    function w.getConnectedAddress() return p.remoteAddress() end
    function w.getStargateEnergy() return p.energyAvailable() end
    function w.getIris()
        local s = p.irisState()
        if s ~= "Offline" then return s end
        return nil
    end
    function w.getIrisProgressPercentage() return SGCRAFT_IRIS[p.irisState()] end
    function w.openIris() return p.openIris() end
    function w.closeIris() return p.closeIris() end
    function w.dialAddress(address) return p.dial(address) end
    -- SGCraft 2.x: ZPM energy and how many ZPMs feed the gate
    if p.zpmEnergy then w.getZpmEnergy = function() return p.zpmEnergy() end end
    w.state = state
    return w
end

local function wrapInterface(name, t)
    local p = peripheral.wrap(name)
    if t == "stargate" then return sgcraftInterface(p), name, t end
    return p, name, t
end

local function findInterface()
    if CONFIG.interfaceName then
        if peripheral.isPresent(CONFIG.interfaceName) then
            return wrapInterface(CONFIG.interfaceName, peripheral.getType(CONFIG.interfaceName))
        end
        return nil
    end
    for _, t in ipairs({ "advanced_crystal_interface", "crystal_interface", "basic_interface", "stargate" }) do
        local p = peripheral.find(t)
        if p then return wrapInterface(peripheral.getName(p), t) end
    end
end

local function has(method)
    return iface ~= nil and type(iface[method]) == "function"
end

-- calls an interface method, returns nil if it does not exist or fails
local function call(method, ...)
    if not has(method) then return nil end
    local result = table.pack(pcall(iface[method], ...))
    if result[1] then return table.unpack(result, 2, result.n) end
    return nil
end

local function feedbackText(code)
    if type(code) ~= "number" then return tostring(code) end
    local recent, desc = call("getRecentFeedback")
    if recent == code and type(desc) == "string" and desc ~= "" then
        desc = desc:gsub("_", " ")
        return (desc:gsub("^%l", string.upper))
    end
    return FEEDBACK[code] or ("Feedback code " .. code)
end

local gate = {
    state = "OFFLINE",
    chevrons = 0,
    connected = false,
    outgoing = false,       -- best guess, fail-safe is "incoming"
    incomingChevrons = false,
    typeName = "Stargate",
    themeId = nil,
    localAddress = nil,
    variant = nil,
    remote = nil,           -- address on the other side of the wormhole, if known
    lastIncoming = nil,
}

local dial = { active = false, abort = false, interrupted = false, entry = nil, address = nil, endedAt = -10 }
local autoClose = { timer = nil, deadline = nil, closedAt = -10 }
local message = { text = "", color = colors.lightGray }

local function setMessage(text, color)
    message.text = text or ""
    message.color = color or colors.lightGray
end

local function detectGate()
    gate.typeName, gate.themeId = "Stargate", nil
    local t = call("getStargateType")
    if type(t) == "string" then
        for _, g in ipairs(GATE_TYPES) do
            if t:find(g.match, 1, true) then
                gate.typeName, gate.themeId = g.name, g.theme
                break
            end
        end
    end
    local v = call("getStargateVariant")
    gate.variant = type(v) == "string" and v:gsub("^.*:", "") or nil
    if gate.variant == "empty" or gate.variant == "" then gate.variant = nil end
    if gate.variant then
        for _, m in ipairs(VARIANT_THEMES) do
            if gate.variant:lower():find(m[1]) then
                gate.themeId = m[2]
                break
            end
        end
    end
    gate.localAddress = toAddress(call("getLocalAddress"))
end

local function refreshGate()
    if not iface then
        gate.state, gate.chevrons, gate.connected = "OFFLINE", 0, false
        return
    end
    gate.chevrons = call("getChevronsEngaged") or 0
    gate.connected = call("isStargateConnected") == true
    local dialingOut = call("isStargateDialingOut")

    if gate.connected then
        if dialingOut ~= nil then gate.outgoing = dialingOut end
        gate.state = gate.outgoing and "OPEN" or "INCOMING"
    elseif dial.active then
        gate.state = "DIALING"
    elseif gate.chevrons > 0 then
        local incoming = gate.incomingChevrons
        if dialingOut ~= nil then incoming = not dialingOut end
        gate.state = incoming and "INCOMING" or "DIALING"
    else
        gate.state = "IDLE"
        gate.remote = nil
        gate.incomingChevrons = false
    end
end

local function disarmAutoClose()
    if autoClose.timer then os.cancelTimer(autoClose.timer) end
    autoClose.timer, autoClose.deadline = nil, nil
end

local function armAutoClose(seconds)
    disarmAutoClose()
    autoClose.deadline = os.clock() + seconds
    autoClose.timer = os.startTimer(seconds)
end

---------------------------------------------------------------------------
-- Dialing (runs in its own coroutine)
---------------------------------------------------------------------------

local DialFailed = {}

local function redrawLater()
    os.queueEvent("dialer_redraw")
end

local function waitUntil(predicate, timeout)
    local deadline = os.clock() + timeout
    while not predicate() do
        if dial.abort then return false end
        if os.clock() > deadline then return false end
        sleep(0.1)
    end
    return true
end

local function fail(reason)
    error({ DialFailed, reason }, 0)
end

local function checkFeedback(fb, allowed)
    if type(fb) ~= "number" or fb >= 0 then return end
    for _, a in ipairs(allowed or {}) do
        if fb == a then return end
    end
    fail(feedbackText(fb))
end

local function dialSuccess()
    gate.outgoing = true
    if dial.entry then
        dial.entry.last = "ok"
        saveBook()
    end
    if db.settings.autoClose then armAutoClose(CONFIG.autoCloseIdle) end
    setMessage("Connection established, wormhole forming...", colors.lightBlue)
end

local function runDialSGCraft()
    local address = dial.address
    if type(address) ~= "string" then fail("That is a Stargate Journey address, this gate is SGCraft") end
    local s = iface.state()
    if s ~= "Idle" then fail("The gate is busy") end
    redrawLater()
    local ok, err = pcall(iface.dialAddress, address)
    if not ok then fail(sgcraftError(err)) end
    local connected = waitUntil(function()
        local st, chevrons = iface.state()
        if chevrons ~= gate.chevrons then
            gate.chevrons = chevrons
            redrawLater()
        end
        if st == "Idle" then fail("The gate stopped dialing") end
        return st == "Connected"
    end, CONFIG.stepTimeout)
    if dial.abort then return end
    if not connected then fail("No connection was established") end
    dialSuccess()
end

local function runDial()
    if iface.sgcraft then return runDialSGCraft() end
    if type(dial.address) == "string" then fail("That is an SGCraft address, this gate is Stargate Journey") end
    local address = stripOrigin(dial.address)
    address[#address + 1] = 0

    local openName = has("openChevron") and "openChevron" or (has("raiseChevron") and "raiseChevron")
    local closeName = has("closeChevron") and "closeChevron" or (has("lowerChevron") and "lowerChevron")
    local canRotate = has("rotateClockwise") and has("isCurrentSymbol") and openName and closeName
    local useEngage = has("engageSymbol") and (not canRotate or db.settings.fastDial)
    if not useEngage and not canRotate then fail("This interface can't dial this gate") end

    -- start from a clean gate
    if has("isChevronOpen") and call("isChevronOpen") then call(closeName) end
    if (call("getChevronsEngaged") or 0) > 0 then
        call("disconnectStargate")
        sleep(0.5)
    end

    local function chevronsAtLeast(n)
        return function()
            gate.chevrons = call("getChevronsEngaged") or 0
            return gate.chevrons >= n
        end
    end

    for i, symbol in ipairs(address) do
        if dial.abort then return end
        local last = (i == #address)
        setMessage("Encoding chevron " .. i .. "  (symbol " .. symbol .. ")", colors.lightGray)
        redrawLater()

        if useEngage then
            checkFeedback(call("engageSymbol", symbol))
            if not last then
                if not waitUntil(chevronsAtLeast(i), CONFIG.stepTimeout) then
                    if dial.abort then return end
                    fail("Chevron " .. i .. " did not lock")
                end
                if not db.settings.fastDial then sleep(CONFIG.symbolDelay) end
            end
        else
            local delay = db.settings.fastDial and 0 or CONFIG.chevronDelay
            if not call("isCurrentSymbol", symbol) then
                if i % 2 == 0 then
                    call("rotateClockwise", symbol)
                else
                    call("rotateAntiClockwise", symbol)
                end
                if not waitUntil(function() return call("isCurrentSymbol", symbol) end, CONFIG.stepTimeout) then
                    if dial.abort then return end
                    call("endRotation")
                    fail("The ring did not reach symbol " .. symbol)
                end
            end
            sleep(delay)
            if dial.abort then return end
            checkFeedback(call(openName), { -26 })
            sleep(delay)
            if dial.abort then return end
            checkFeedback(call(closeName), { -2, -27 })
            if not last then
                if not waitUntil(chevronsAtLeast(i), 5) then
                    if dial.abort then return end
                    fail("Chevron " .. i .. " did not lock")
                end
                sleep(delay)
            end
        end
        redrawLater()
    end

    -- point of origin encoded, wait for the wormhole
    if not waitUntil(function() return call("isStargateConnected") == true end, CONFIG.connectTimeout) then
        if dial.abort then return end
        local code = call("getRecentFeedback")
        fail(type(code) == "number" and code < 0 and feedbackText(code) or "No connection was established")
    end
    dialSuccess()
end

local function dialerTask()
    while true do
        os.pullEvent("dialer_start")
        local ok, err = pcall(runDial)
        if not ok and err == "Terminated" then error(err, 0) end

        if dial.abort then
            if dial.interrupted then
                setMessage("Dialing interrupted by an incoming wormhole", colors.red)
            else
                call("endRotation")
                if has("isChevronOpen") and call("isChevronOpen") then
                    local closeName = has("closeChevron") and "closeChevron" or "lowerChevron"
                    call(closeName)
                end
                if call("isStargateConnected") ~= true then call("disconnectStargate") end
                setMessage("Dialing aborted", colors.orange)
            end
        elseif not ok then
            local reason = (type(err) == "table" and err[1] == DialFailed) and err[2] or tostring(err)
            if dial.entry then
                dial.entry.last = "fail"
                saveBook()
            end
            if call("isStargateConnected") ~= true then call("disconnectStargate") end
            setMessage("Dialing failed: " .. reason, colors.red)
        end

        dial.active, dial.abort, dial.interrupted = false, false, false
        dial.endedAt = os.clock()
        refreshGate()
        redrawLater()
    end
end

---------------------------------------------------------------------------
-- Screen setup
---------------------------------------------------------------------------

local native = term.current()
local monitor, monitorName
if args[1] == "monitor" then
    monitor = peripheral.find("monitor")
    if not monitor then error("No monitor attached", 0) end
    if not monitor.isColor() then error("Monitor mode needs an advanced monitor", 0) end
    monitorName = peripheral.getName(monitor)
    monitor.setTextScale(CONFIG.monitorScale)
end
local target = monitor or native
if monitor then
    native.setBackgroundColor(colors.black)
    native.setTextColor(colors.white)
    native.clear()
    local lines = { "Personal Dialer is running on monitor " .. monitorName .. ".",
        "Touch the monitor, or type here to search.", "Arrow keys select, Enter dials, Ctrl+Q quits." }
    for i, l in ipairs(lines) do
        native.setCursorPos(1, i)
        native.write(l)
    end
end
local W, H = target.getSize()
local screen = window.create(target, 1, 1, W, H, true)
term.redirect(screen)

local search = { value = "", max = 40 }
local visible, sel, top = {}, 1, 1
local modal = nil
local hits = {}
local cursor = nil
local held = {}
local lastClick = { vi = nil, time = 0 }
local running = true
local gateView = false -- the gate picture instead of the list

local function theme()
    local id = db.settings.theme
    if id == "auto" or not THEMES[id] then id = gate.themeId or "milky_way" end
    return THEMES[id]
end

local function themeLabel()
    if db.settings.theme == "auto" or not THEMES[db.settings.theme] then
        return "Auto (" .. theme().name .. ")"
    end
    return THEMES[db.settings.theme].name
end

local FOOTER_WIDTH = 51

local function layout()
    local w, h = term.getSize()
    local L = { w = w, h = h }
    L.footerRows = (w >= FOOTER_WIDTH) and 1 or 2
    L.footerY = h - L.footerRows + 1
    L.messageY = L.footerY - 1
    L.chevronY = L.messageY - 1
    L.listTop = 3
    L.listBottom = L.chevronY - 1
    L.perPage = math.max(1, math.floor((L.listBottom - L.listTop + 1) / 2))
    -- wide screens (big monitors) show the gate next to the list
    L.lw = w
    if w >= 80 and L.listBottom - L.listTop >= 8 then
        L.side = math.floor(w * 0.4)
        L.lw = w - L.side
    end
    return L
end

---------------------------------------------------------------------------
-- Drawing primitives
---------------------------------------------------------------------------

local function writeAt(x, y, s, fg, bg)
    term.setCursorPos(x, y)
    if fg then term.setTextColor(fg) end
    if bg then term.setBackgroundColor(bg) end
    term.write(s)
end

local function fill(x, y, w, h, bg)
    if w <= 0 or h <= 0 then return end
    local line = string.rep(" ", w)
    term.setBackgroundColor(bg)
    for yy = y, y + h - 1 do
        term.setCursorPos(x, yy)
        term.write(line)
    end
end

local function hit(x1, y1, x2, y2, fn)
    hits[#hits + 1] = { x1, y1, x2, y2, fn }
end

local function button(x, y, label, fg, bg, fn)
    writeAt(x, y, label, fg, bg)
    if fn then hit(x, y, x + #label - 1, y, fn) end
    return x + #label
end

local function drawField(x, y, w, field, focused, placeholder)
    local shown = field.value
    if #shown > w - 1 then shown = shown:sub(-(w - 1)) end
    if shown == "" and placeholder then
        local text = fit(placeholder, w)
        writeAt(x, y, text .. string.rep(" ", w - #text), colors.lightGray, colors.gray)
    else
        writeAt(x, y, shown .. string.rep(" ", w - #shown), colors.white, colors.gray)
    end
    if focused then cursor = { x + #shown, y } end
end

local function fieldInput(field, e)
    if e[1] == "char" or e[1] == "paste" then
        local s = tostring(e[2]):gsub("[\r\n]", " ")
        field.value = (field.value .. s):sub(1, field.max or 40)
        return true
    elseif e[1] == "key" and e[2] == keys.backspace then
        field.value = field.value:sub(1, -2)
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- List state
---------------------------------------------------------------------------

local function ensureVisible()
    local L = layout()
    if sel < top then top = sel end
    if sel > top + L.perPage - 1 then top = sel - L.perPage + 1 end
    top = clamp(top, 1, math.max(1, #visible - L.perPage + 1))
end

local function selectedEntry()
    local idx = visible[sel]
    return idx and db.entries[idx], idx
end

local function refilter(keep)
    keep = keep or selectedEntry()
    local q = search.value:lower()
    visible = {}
    for i, e in ipairs(db.entries) do
        if q == "" or e.name:lower():find(q, 1, true) or e.note:lower():find(q, 1, true)
            or formatAddress(e.address):find(q, 1, true) then
            visible[#visible + 1] = i
        end
    end
    for vi, idx in ipairs(visible) do
        if db.entries[idx] == keep then sel = vi end
    end
    sel = clamp(sel, 1, math.max(1, #visible))
    ensureVisible()
end

local function moveSelection(delta)
    if #visible == 0 then return end
    sel = clamp(sel + delta, 1, #visible)
    ensureVisible()
end

local function moveEntry(vi, dir)
    if search.value ~= "" then
        setMessage("Clear the search to reorder addresses", colors.orange)
        return
    end
    local i = visible[vi]
    local j = i and i + dir
    if not i or j < 1 or j > #db.entries then return end
    db.entries[i], db.entries[j] = db.entries[j], db.entries[i]
    sel = vi + dir
    saveBook()
    refilter(db.entries[j])
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

local function startDial(entry)
    if not entry then
        setMessage("Select an address first", colors.orange)
        return
    end
    if not entry.address then
        setMessage(entry.name .. " has no address yet - [E] to add one", colors.orange)
        return
    end
    if not iface then
        setMessage("No stargate interface connected", colors.red)
        return
    end
    if dial.active then
        setMessage("Already dialing - CLOSE aborts", colors.orange)
        return
    end
    refreshGate()
    if gate.connected or gate.state == "INCOMING" then
        setMessage("The gate is busy", colors.red)
        return
    end
    disarmAutoClose()
    dial.active, dial.abort, dial.interrupted = true, false, false
    dial.entry, dial.address = entry, stripOrigin(entry.address)
    gate.outgoing, gate.remote = true, stripOrigin(entry.address)
    gate.state = "DIALING"
    setMessage("Dialing " .. entry.name .. "...", colors.lightGray)
    os.queueEvent("dialer_start")
end

local function closeGate()
    if dial.active then
        dial.abort = true
        call("endRotation")
        setMessage("Aborting...", colors.orange)
        return
    end
    if not iface then return end
    refreshGate()
    if gate.connected or gate.chevrons > 0 then
        disarmAutoClose()
        call("disconnectStargate")
        setMessage(gate.state == "INCOMING" and "Trying to close the incoming wormhole" or "Closing the gate", colors.lightGray)
    else
        setMessage("The gate is already idle", colors.gray)
    end
end

local function toggleAutoClose()
    db.settings.autoClose = not db.settings.autoClose
    saveBook()
    if not db.settings.autoClose then
        disarmAutoClose()
    elseif gate.state == "OPEN" then
        armAutoClose(CONFIG.autoCloseIdle)
    end
    setMessage("Auto-close " .. (db.settings.autoClose and "on" or "off"), colors.lightGray)
end

local function quit()
    if dial.active then
        dial.abort = true
        call("endRotation")
        call("disconnectStargate")
    end
    running = false
end

---------------------------------------------------------------------------
-- Dialogs
---------------------------------------------------------------------------

local function panel(title, width, height)
    local L = layout()
    width = math.min(width, L.w - 2)
    height = math.min(height, L.h - 2)
    local x = math.floor((L.w - width) / 2) + 1
    local y = math.floor((L.h - height) / 2) + 1
    local th = theme()
    fill(x, y, width, height, colors.lightGray)
    fill(x, y, width, 1, th.header)
    writeAt(x + 1, y, fit(title, width - 2), colors.white, th.header)
    return x, y, width, height
end

local function messageBox(title, lines)
    local L = layout()
    local width = 4
    for _, l in ipairs(lines) do width = math.max(width, #l + 4) end
    width = math.min(width, L.w - 2)
    local wrapped = {}
    for _, l in ipairs(lines) do
        if #l <= width - 4 then
            wrapped[#wrapped + 1] = l
        else
            for _, w in ipairs(wrap(l, width - 4)) do wrapped[#wrapped + 1] = w end
        end
    end
    modal = {
        draw = function()
            local x, y, w, h = panel(title, width, #wrapped + 5)
            for i, l in ipairs(wrapped) do
                if y + i + 1 < y + h - 2 then writeAt(x + 2, y + i + 1, l, colors.black, colors.lightGray) end
            end
            button(x + w - 7, y + h - 2, " OK ", colors.white, colors.gray, function() modal = nil end)
        end,
        event = function(e)
            if e[1] == "key" and (e[2] == keys.enter or e[2] == keys.numPadEnter or e[2] == keys.f1 or e[2] == keys.h) then modal = nil end
        end,
    }
end

local function confirm(title, text, onYes)
    local focusYes = false
    modal = {
        draw = function()
            local lines = wrap(text, 36)
            local x, y, w, h = panel(title, 40, #lines + 5)
            for i, l in ipairs(lines) do writeAt(x + 2, y + 1 + i, l, colors.black, colors.lightGray) end
            local by = y + h - 2
            local yes, no = focusYes and "[Yes]" or " Yes ", focusYes and " No " or "[No]"
            local bx = x + w - 2 - #no - #yes
            bx = button(bx, by, yes, colors.white, colors.red, function() modal = nil onYes() end) + 1
            button(bx, by, no, colors.white, colors.gray, function() modal = nil end)
        end,
        event = function(e)
            if e[1] == "char" then
                local c = e[2]:lower()
                if c == "y" then modal = nil onYes() elseif c == "n" then modal = nil end
            elseif e[1] == "key" then
                local k = e[2]
                if k == keys.left or k == keys.right or k == keys.tab then
                    focusYes = not focusYes
                elseif k == keys.enter or k == keys.numPadEnter then
                    modal = nil
                    if focusYes then onYes() end
                end
            end
        end,
    }
end

local function openEditor(entry)
    local prefill = ""
    if not entry and gate.lastIncoming and not findByAddress(gate.lastIncoming) then
        prefill = formatAddress(gate.lastIncoming)
    end
    local fields = {
        { label = "Name",    value = entry and entry.name or "", max = 40 },
        { label = "Address", value = entry and entry.address and formatAddress(entry.address) or prefill, max = 40 },
        { label = "Note",    value = entry and entry.note or "", max = 40 },
    }
    local focus, err = 1, nil
    local FOCUS_SAVE, FOCUS_CANCEL = 4, 5

    local function submit()
        local address, why
        if trim(fields[2].value) ~= "" then
            address, why = parseAddress(fields[2].value)
            if not address then
                err, focus = why, 2
                return
            end
        end
        local name = trim(fields[1].value)
        if name == "" then
            if not address then
                err, focus = "Enter a name or an address", 1
                return
            end
            name = formatAddress(address)
        end
        local note = trim(fields[3].value)
        local item = entry
        if item then
            if not (address and item.address and sameAddress(item.address, address)) then item.last = nil end
            item.name, item.address, item.note = name, address, note
            setMessage("Saved " .. name, colors.lightGray)
        else
            item = { name = name, address = address, note = note }
            db.entries[#db.entries + 1] = item
            setMessage("Added " .. name, colors.lightGray)
        end
        saveBook()
        modal = nil
        if search.value ~= "" and entry == nil then search.value = "" end
        refilter(item)
    end

    modal = {
        draw = function()
            local x, y, w, h = panel(entry and "Edit address" or "Add address", 46, 10)
            for i, f in ipairs(fields) do
                local fy = y + 1 + i
                writeAt(x + 1, fy, (focus == i and ">" or " ") .. f.label .. ":", focus == i and colors.black or colors.gray, colors.lightGray)
                drawField(x + 11, fy, w - 13, f, focus == i)
                hit(x + 1, fy, x + w - 3, fy, function() focus = i end)
            end
            writeAt(x + 2, y + 5, fit("e.g. 26 6 14 31 11 29, or WLDQ-DQB-MT for SGCraft", w - 4), colors.gray, colors.lightGray)
            if err then writeAt(x + 2, y + 6, fit(err, w - 4), colors.red, colors.lightGray) end
            local by = y + h - 2
            local saveLbl = focus == FOCUS_SAVE and "[Save]" or " Save "
            local cancelLbl = focus == FOCUS_CANCEL and "[Cancel]" or " Cancel "
            local bx = x + w - 2 - #saveLbl - 1 - #cancelLbl
            bx = button(bx, by, saveLbl, colors.white, colors.green, submit) + 1
            button(bx, by, cancelLbl, colors.white, colors.gray, function() modal = nil end)
        end,
        event = function(e)
            if e[1] == "key" then
                local k = e[2]
                if k == keys.tab or k == keys.down then
                    focus = focus % 5 + 1
                elseif k == keys.up then
                    focus = (focus - 2) % 5 + 1
                elseif k == keys.enter or k == keys.numPadEnter then
                    if focus < 3 then
                        focus = focus + 1
                    elseif focus == FOCUS_CANCEL then
                        modal = nil
                    else
                        submit()
                    end
                elseif focus <= 3 then
                    fieldInput(fields[focus], e)
                end
            elseif (e[1] == "char" or e[1] == "paste") and focus <= 3 then
                fieldInput(fields[focus], e)
            end
        end,
    }
end

local function removeSelected()
    local entry, idx = selectedEntry()
    if not entry then return end
    confirm("Remove address", "Remove " .. entry.name .. " " .. formatAddress(entry.address) .. " from the address book?", function()
        table.remove(db.entries, idx)
        saveBook()
        refilter()
        setMessage("Removed " .. entry.name, colors.lightGray)
    end)
end

local function editSelected()
    local entry = selectedEntry()
    if entry then openEditor(entry) end
end

local function cycleTheme()
    local i = 1
    for n, id in ipairs(THEME_ORDER) do
        if id == db.settings.theme then i = n end
    end
    db.settings.theme = THEME_ORDER[i % #THEME_ORDER + 1]
    saveBook()
end

local function toggleFast()
    db.settings.fastDial = not db.settings.fastDial
    saveBook()
end

local function irisPercent()
    return call("getIrisProgressPercentage") or call("getIrisProgress")
end

local function toggleIris()
    if not has("getIris") or not call("getIris") then
        setMessage("No iris installed on this gate", colors.orange)
        return
    end
    local p = irisPercent()
    if type(p) == "number" and p > 0 then call("openIris") else call("closeIris") end
end

local function openInfo()
    local function lines()
        local out = {}
        local function add(k, v, c) out[#out + 1] = { k, tostring(v), c } end
        if not iface then
            add("Interface", "none found", colors.red)
        else
            local kind = ({ basic_interface = "Basic", crystal_interface = "Crystal",
                advanced_crystal_interface = "Advanced crystal", stargate = "SGCraft" })[ifaceType] or tostring(ifaceType)
            add("Interface", kind)
            add("Peripheral", ifaceName)
            local gen = call("getStargateGeneration")
            add("Stargate", gate.typeName .. (gen and ("  gen " .. tostring(gen)) or "") .. (gate.variant and ("  " .. gate.variant) or ""))
            add("Local address", gate.localAddress and formatAddress(gate.localAddress) or "advanced interface needed",
                gate.localAddress and colors.blue or colors.gray)
            add("Status", gate.state .. ", " .. gate.chevrons .. " chevrons engaged")
            local open = call("getOpenTime")
            if gate.connected and type(open) == "number" then add("Open for", math.floor(open / 20) .. " s") end
            local se = call("getStargateEnergy")
            if se then add("Gate energy", commas(se) .. (iface.sgcraft and " SU" or " FE")) end
            local zpm, zpms = call("getZpmEnergy")
            if type(zpms) == "number" and zpms > 0 then add("ZPM", zpms .. " x, " .. commas(zpm) .. " SU") end
            local ie, cap = call("getEnergy"), call("getEnergyCapacity")
            if ie then add("Buffer", commas(ie) .. (cap and (" / " .. commas(cap)) or "") .. " FE") end
            if has("getIris") then
                if call("getIris") then
                    local p = irisPercent()
                    add("Iris", type(p) == "number" and (p .. "% closed") or "installed")
                else
                    add("Iris", "not installed", colors.gray)
                end
            end
            local code = call("getRecentFeedback")
            if type(code) == "number" then add("Last feedback", feedbackText(code), code < 0 and colors.red or nil) end
        end
        add("Theme", themeLabel())
        add("Dial mode", db.settings.fastDial and "Fast" or "Normal")
        return out
    end

    modal = {
        draw = function()
            local info = lines()
            local x, y, w, h = panel("Gate info", 49, #info + 5)
            local by = y + h - 2
            for i, row in ipairs(info) do
                if y + i < by - 1 then
                    writeAt(x + 2, y + i, fit(row[1], 14), colors.gray, colors.lightGray)
                    writeAt(x + 17, y + i, fit(row[2], w - 19), row[3] or colors.black, colors.lightGray)
                end
            end
            local bx = x + 2
            bx = button(bx, by, " Theme ", colors.white, colors.gray, cycleTheme) + 1
            bx = button(bx, by, " Mode ", colors.white, colors.gray, toggleFast) + 1
            if has("getIris") then bx = button(bx, by, " Iris ", colors.white, colors.gray, toggleIris) + 1 end
            button(x + w - 6, by, " OK ", colors.white, colors.green, function() modal = nil end)
        end,
        event = function(e)
            if e[1] == "char" then
                local c = e[2]:lower()
                if c == "t" then cycleTheme() elseif c == "m" then toggleFast() elseif c == "i" then toggleIris() end
            elseif e[1] == "key" and (e[2] == keys.enter or e[2] == keys.numPadEnter or e[2] == keys.f3
                or ((held[keys.leftCtrl] or held[keys.rightCtrl]) and e[2] == keys.i)) then
                modal = nil
            end
        end,
    }
end

local function openHelp()
    messageBox("Personal Dialer " .. VERSION .. " - help", {
        "Type to search. Click selects, double-click",
        "or Enter dials.",
        "[+] Ctrl+N  add        [-] Ctrl+D  remove",
        "[E] Ctrl+E  edit       [i] Ctrl+I  gate info",
        "Shift+Up/Down or the \30\31 arrows: move address",
        "CLOSE  Ctrl+X  close gate / abort dialing",
        "Chevron bar or Ctrl+G: gate picture",
        "[x] Ctrl+A auto-close    QUIT Ctrl+Q exit",
        "",
        "Auto-close shuts an outgoing wormhole " .. CONFIG.autoCloseDelay .. "s",
        "after someone steps through (" .. CONFIG.autoCloseIdle .. "s if unused).",
        "Right bar: green = dial worked, red = failed.",
    })
end

---------------------------------------------------------------------------
-- Main screen
---------------------------------------------------------------------------

local function chevronColor(th, i, total)
    if i == total then return th.master end
    if th.palette then return th.palette[(i - 1) % #th.palette + 1] end
    return th.lit
end

-- symbols on the chevron bar, chevrons in the address, chevrons locked
local function chevronState()
    local symbols, total, lit
    if dial.active and dial.address then
        symbols = chevronSymbols(dial.address)
        total = #symbols
        lit = math.min(gate.chevrons, total)
    else
        total = math.max(7, gate.chevrons)
        lit = gate.chevrons
        if gate.connected then
            if gate.remote then
                symbols = chevronSymbols(gate.remote)
                total = #symbols
            end
            lit = total
        end
    end
    return symbols, total, lit
end

---------------------------------------------------------------------------
-- Gate picture: drawn with teletext characters, 2 x 3 pixels per character
---------------------------------------------------------------------------

local HEXDIGIT = {}
for i = 0, 15 do HEXDIGIT[2 ^ i] = ("0123456789abcdef"):sub(i + 1, i + 1) end
-- chevron positions (angle / 40 degrees, clockwise from the top) -> locking order, 9 = master
local POSITION_OF_SLOT = { [1] = 1, [2] = 2, [3] = 3, [6] = 4, [7] = 5, [8] = 6, [4] = 7, [5] = 8, [0] = 9 }
-- stone, shadow, symbol track, symbols
local RING_COLORS = {
    universe = { colors.gray, colors.black, colors.gray, colors.lightGray },
    tollan   = { colors.white, colors.lightGray, colors.white, colors.white },
    classic  = { colors.brown, colors.gray, colors.brown, colors.lightGray },
    movie    = { colors.lightGray, colors.brown, colors.gray, colors.lightGray },
    pegasus  = { colors.gray, colors.black, colors.gray, colors.lightBlue },
    atlantis = { colors.gray, colors.black, colors.gray, colors.cyan },
}
local atan2 = math.atan2 or math.atan

local function drawGatePicture(x0, y0, cols, rows, th)
    if cols < 4 or rows < 3 then return end
    local w, h = cols * 2, rows * 3
    local px = {}
    for i = 1, w * h do px[i] = colors.black end
    local cx, cy = w / 2, h / 2
    local R = math.min(w, h) / 2 / 1.1
    local themeId = db.settings.theme ~= "auto" and db.settings.theme or gate.themeId
    local rc = RING_COLORS[themeId] or { colors.lightGray, colors.gray, colors.gray, colors.lightGray }
    local plain = themeId == "tollan" or themeId == "universe"
    local t = os.clock()

    local _, total, lit = chevronState()
    local on = {}
    for i = 1, math.min(lit, total) do
        on[i >= total and 9 or i] = chevronColor(th, i, total)
    end
    local iris = has("getIris") and call("getIris") and irisPercent()
    iris = type(iris) == "number" and iris or nil
    local open = gate.connected
    local symbolsOnRing = (themeId == "pegasus" or themeId == "atlantis" or themeId == "universe") and 36 or 39

    for y = 1, h do
        for x = 1, w do
            local dx, dy = x - 0.5 - cx, y - 0.5 - cy
            local d = math.sqrt(dx * dx + dy * dy) / R
            if d <= 1.08 then
                local a = math.deg(atan2(dx, -dy)) % 360
                local c
                if d <= 0.66 then
                    local hh = d / 0.66
                    if iris and iris > 0 and d >= (1 - iris / 100) * 0.66 then
                        local q = a / 18 + hh * 2.4
                        c = (q - math.floor(q) < 0.15) and colors.gray or colors.lightGray
                    elseif open then
                        local v = 0.24 + 0.46 * (1 - hh) ^ 1.4
                            + 0.17 * math.sin(hh * 15 - t * 3 + 1.3 * hh * math.sin(math.rad(a) * 2 + t * 0.6))
                        c = v < 0.36 and colors.blue or v < 0.56 and colors.cyan or v < 0.8 and colors.lightBlue or colors.white
                    end
                elseif d <= 0.70 then
                    c = rc[2]
                elseif d <= 0.86 and not plain then
                    local seg = a / (360 / symbolsOnRing) + 0.5
                    local f = seg - math.floor(seg)
                    c = (f > 0.33 and f < 0.67 and d > 0.75 and d < 0.82) and rc[4] or rc[3]
                elseif d <= 1 then
                    c = (d > 0.97 or d < 0.88 and not plain) and rc[2] or rc[1]
                end
                -- chevrons
                if d >= 0.8 and d <= 1.06 then
                    local slot = math.floor(a / 40 + 0.5) % 9
                    local diff = math.abs(a - slot * 40)
                    if diff > 180 then diff = 360 - diff end
                    local f = (d - 0.8) / 0.26
                    local hw = 2.5 + 6 * f
                    if diff <= hw then
                        local pos = POSITION_OF_SLOT[slot]
                        c = (diff <= hw * 0.6 and f > 0.12 and f < 0.86) and (on[pos] or colors.brown) or colors.gray
                    end
                end
                if c then px[(y - 1) * w + x] = c end
            end
        end
    end

    -- 2 x 3 pixels per character: the two most common colours of each cell
    for row = 1, rows do
        local text, fg, bg = {}, {}, {}
        for col = 1, cols do
            local b = (row - 1) * 3 * w + (col - 1) * 2 + 1
            local p = { px[b], px[b + 1], px[b + w], px[b + w + 1], px[b + 2 * w], px[b + 2 * w + 1] }
            local count, first, second = {}, nil, nil
            for i = 1, 6 do count[p[i]] = (count[p[i]] or 0) + 1 end
            for c, n in pairs(count) do
                if not first or n > count[first] then
                    second, first = first, c
                elseif not second or n > count[second] then
                    second = c
                end
            end
            if not second then
                text[col], fg[col], bg[col] = " ", HEXDIGIT[first], HEXDIGIT[first]
            else
                local back, fore = first, second
                if p[6] == second then back, fore = second, first end
                local code = 128
                for i = 1, 5 do
                    if p[i] == fore then code = code + 2 ^ (i - 1) end
                end
                text[col], fg[col], bg[col] = string.char(code), HEXDIGIT[fore], HEXDIGIT[back]
            end
        end
        term.setCursorPos(x0, y0 + row - 1)
        term.blit(table.concat(text), table.concat(fg), table.concat(bg))
    end
end

local function drawChevrons(L, th)
    local y = L.chevronY
    fill(1, y, L.w, 1, colors.black)

    local symbols, total, lit = chevronState()

    local st = STATE_STYLE[gate.state] or STATE_STYLE.OFFLINE
    local label = st.label
    if gate.state == "OPEN" and autoClose.deadline then
        label = label .. " " .. math.max(0, math.ceil(autoClose.deadline - os.clock())) .. "s"
    end
    label = " " .. label .. " "

    local space = L.w - #label - 2
    local cell = 4
    if not symbols or total * cell > space then symbols, cell = nil, 2 end

    local x = 2
    for i = 1, total do
        local on = i <= lit
        local pending = dial.active and i == lit + 1
        local c = on and chevronColor(th, i, total) or (pending and colors.lightGray or colors.gray)
        writeAt(x, y, "\31", c, colors.black)
        if symbols and symbols[i] then
            writeAt(x + 1, y, tostring(symbols[i]), on and colors.white or colors.gray, colors.black)
        end
        x = x + cell
    end

    writeAt(L.w - #label + 1, y, label, st.fg, st.bg)
end

local function drawFooter(L, th)
    fill(1, L.footerY, L.w, L.footerRows, colors.black)
    local y = L.footerY
    local x = 1
    local tools = { { "+", function() openEditor(nil) end }, { "-", removeSelected }, { "E", editSelected },
                    { "i", openInfo }, { "?", openHelp } }
    for _, t in ipairs(tools) do
        writeAt(x, y, "[", colors.lightGray, colors.gray)
        writeAt(x + 1, y, t[1], colors.white, colors.gray)
        writeAt(x + 2, y, "]", colors.lightGray, colors.gray)
        hit(x, y, x + 2, y, t[2])
        x = x + 3
    end
    x = x + 1
    local box = db.settings.autoClose and "[x]" or "[ ]"
    writeAt(x, y, box, db.settings.autoClose and colors.lime or colors.lightGray, colors.black)
    writeAt(x + 3, y, "Auto-close", colors.lightGray, colors.black)
    hit(x, y, x + 12, y, toggleAutoClose)

    local right = { { " DIAL ", colors.black, th.button, function() startDial(selectedEntry()) end },
                    { " CLOSE ", colors.white, colors.red, closeGate },
                    { " QUIT ", colors.white, colors.gray, quit } }
    local width = 0
    for _, b in ipairs(right) do width = width + #b[1] + 1 end
    width = width - 1
    local ry = L.footerY + L.footerRows - 1
    local rx = L.w - width + 1
    for _, b in ipairs(right) do
        rx = button(rx, ry, b[1], b[2], b[3], b[4]) + 1
    end
end

local function clickEntry(vi)
    local now = os.clock()
    if lastClick.vi == vi and sel == vi and now - lastClick.time < 0.6 then
        lastClick.vi = nil
        startDial(selectedEntry())
        return
    end
    sel = vi
    lastClick.vi, lastClick.time = vi, now
end

local function drawList(L, th)
    local listH = L.perPage * 2
    if #visible == 0 then
        local msg = #db.entries == 0 and "The address book is empty - press + to add one"
            or "No address matches \"" .. search.value .. "\""
        msg = fit(msg, L.lw - 2)
        writeAt(math.floor((L.lw - #msg) / 2) + 1, L.listTop + 1, msg, colors.gray, colors.black)
        return
    end

    local canMove = search.value == ""
    for row = 0, L.perPage - 1 do
        local vi = top + row
        local idx = visible[vi]
        if not idx then break end
        local entry = db.entries[idx]
        local y = L.listTop + row * 2
        local selected = (vi == sel)
        local bg = selected and colors.gray or colors.black
        fill(1, y, L.lw - 2, 2, bg)

        local cw = L.lw - 6
        writeAt(2, y, fit(entry.name, cw), entry.address and colors.white or colors.lightGray, bg)
        local addr = fit(entry.address and formatAddress(entry.address) or "no address yet", cw)
        writeAt(2, y + 1, addr, entry.address and th.address or colors.gray, bg)
        if entry.note ~= "" and #addr + 4 < cw then
            writeAt(2 + #addr, y + 1, fit("  " .. entry.note, cw - #addr), selected and colors.lightGray or colors.gray, bg)
        end

        local ac = canMove and colors.lightGray or colors.gray
        writeAt(L.lw - 3, y, "\30", ac, bg)
        writeAt(L.lw - 3, y + 1, "\31", ac, bg)
        hit(L.lw - 3, y, L.lw - 3, y, function() moveEntry(vi, -1) end)
        hit(L.lw - 3, y + 1, L.lw - 3, y + 1, function() moveEntry(vi, 1) end)

        local stripe = entry.last == "ok" and colors.lime or entry.last == "fail" and colors.red or colors.gray
        fill(L.lw - 1, y, 1, 2, stripe)

        hit(1, y, L.lw - 4, y + 1, function() clickEntry(vi) end)
    end

    -- scrollbar
    if #visible > L.perPage then
        local maxTop = #visible - L.perPage + 1
        local thumb = math.max(1, math.floor(listH * L.perPage / #visible))
        local pos = math.floor((top - 1) / (maxTop - 1) * (listH - thumb) + 0.5)
        fill(L.lw, L.listTop, 1, listH, colors.gray)
        fill(L.lw, L.listTop + pos, 1, thumb, colors.lightGray)
        hit(L.lw, L.listTop, L.lw, L.listTop + listH - 1, function(_, y)
            if y < L.listTop + pos then
                top = clamp(top - L.perPage, 1, maxTop)
            elseif y >= L.listTop + pos + thumb then
                top = clamp(top + L.perPage, 1, maxTop)
            end
            sel = clamp(sel, top, top + L.perPage - 1)
        end)
    end
end

local function drawMain(L)
    local th = theme()
    term.setBackgroundColor(colors.black)
    term.clear()

    -- title bar
    fill(1, 1, L.w, 1, th.header)
    local count = search.value ~= "" and ("(" .. #visible .. "/" .. #db.entries .. ")") or ("(" .. #db.entries .. ")")
    local title = " Personal Dialer "
    if #title + #count > L.w then title = " " end
    writeAt(1, 1, title, colors.white, th.header)
    writeAt(1 + #title, 1, count, colors.lightGray, th.header)
    -- right side: local address if it fits, otherwise the gate type
    local options = iface and { gate.localAddress and formatAddress(gate.localAddress), gate.typeName } or { "no interface" }
    for i = 1, 2 do
        local right = options[i]
        if right and #title + #count + #right + 2 <= L.w then
            writeAt(L.w - #right, 1, right, iface and th.title or colors.red, th.header)
            break
        end
    end

    -- search
    writeAt(1, 2, " Search:", colors.lightGray, colors.black)
    local fw = L.w - 13
    drawField(10, 2, fw, search, true, "name, address or note")
    hit(10, 2, 9 + fw, 2, function() end)
    button(L.w - 2, 2, " x ", colors.white, colors.red, function() search.value = "" refilter() end)

    local listH = L.listBottom - L.listTop + 1
    if gateView then
        fill(1, L.listTop, L.w, listH, colors.black)
        drawGatePicture(1, L.listTop, L.w, listH, th)
        hit(1, L.listTop, L.w, L.listBottom, function() gateView = false end)
    else
        drawList(L, th)
        if L.side then
            fill(L.lw + 1, L.listTop, L.side, listH, colors.black)
            drawGatePicture(L.lw + 2, L.listTop, L.side - 2, listH, th)
        end
    end
    drawChevrons(L, th)
    -- the chevron bar switches between the list and the gate picture
    hit(1, L.chevronY, L.w - 12, L.chevronY, function() gateView = not gateView end)

    fill(1, L.messageY, L.w, 1, colors.black)
    writeAt(2, L.messageY, fit(message.text, L.w - 2), message.color, colors.black)

    drawFooter(L, th)
end

local function draw()
    local L = layout()
    hits = {}
    cursor = nil
    screen.setVisible(false)

    drawMain(L)
    if modal then
        -- only the dialog is clickable while it is open
        hits = {}
        cursor = nil
        modal.draw(L)
    end

    if cursor then
        term.setCursorPos(cursor[1], cursor[2])
        term.setTextColor(colors.white)
        term.setCursorBlink(true)
    else
        term.setCursorBlink(false)
    end
    screen.setVisible(true)
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

local function click(x, y, button)
    for i = #hits, 1, -1 do
        local h = hits[i]
        if x >= h[1] and x <= h[3] and y >= h[2] and y <= h[4] then
            h[5](x, y, button)
            return true
        end
    end
    return false
end

-- Ctrl+letter shortcuts (letters alone go to the search box)
local CTRL_ACTIONS = {
    [keys.n] = function() openEditor(nil) end,
    [keys.d] = function() removeSelected() end,
    [keys.e] = function() editSelected() end,
    [keys.i] = function() openInfo() end,
    [keys.h] = function() openHelp() end,
    [keys.x] = function() closeGate() end,
    [keys.a] = function() toggleAutoClose() end,
    [keys.q] = function() quit() end,
    [keys.g] = function() gateView = not gateView end,
}

local function mainEvent(e)
    local name = e[1]
    local L = layout()
    local ctrl = held[keys.leftCtrl] or held[keys.rightCtrl]
    if name == "char" or name == "paste" then
        if fieldInput(search, e) then
            gateView = false
            refilter()
        end
    elseif name == "key" then
        local k = e[2]
        local shift = held[keys.leftShift] or held[keys.rightShift]
        if ctrl and CTRL_ACTIONS[k] then
            CTRL_ACTIONS[k]()
        elseif k == keys.backspace then
            fieldInput(search, e)
            refilter()
        elseif k == keys.up then
            if shift then moveEntry(sel, -1) else moveSelection(-1) end
        elseif k == keys.down then
            if shift then moveEntry(sel, 1) else moveSelection(1) end
        elseif k == keys.pageUp then
            moveSelection(-L.perPage)
        elseif k == keys.pageDown then
            moveSelection(L.perPage)
        elseif k == keys.home then
            moveSelection(-#visible)
        elseif k == keys["end"] then
            moveSelection(#visible)
        elseif k == keys.enter or k == keys.numPadEnter then
            startDial(selectedEntry())
        elseif k == keys.insert then
            openEditor(nil)
        elseif k == keys.delete then
            removeSelected()
        elseif k == keys.f1 then
            openHelp()
        elseif k == keys.f3 then
            openInfo()
        elseif k == keys.f4 then
            closeGate()
        elseif k == keys.f5 then
            toggleAutoClose()
        elseif k == keys.f10 then
            quit()
        end
    elseif name == "mouse_scroll" then
        if e[4] >= L.listTop and e[4] <= L.listBottom then
            top = clamp(top + e[2], 1, math.max(1, #visible - L.perPage + 1))
            sel = clamp(sel, top, top + L.perPage - 1)
        end
    end
end

local function eventAddress(e, offset)
    for i = offset, #e do
        if type(e[i]) == "table" then return stripOrigin(e[i]) end
    end
end

local function describeRemote(address)
    if not address or #address == 0 then return nil end
    local entry = findByAddress(address)
    return entry and entry.name or formatAddress(address)
end

local GATE_EVENTS = {
    stargate_chevron_engaged = true, stargate_incoming_wormhole = true, stargate_outgoing_wormhole = true,
    stargate_disconnected = true, stargate_reset = true,
    stargate_deconstructing_entity = true, stargate_reconstructing_entity = true,
    -- SGCraft
    sgDialIn = true, sgDialOut = true, sgChevronEngaged = true, sgChevronUnset = true, sgStargateStateChange = true,
    sgIrisStateChange = true,
}

local function interruptDial()
    if dial.active then
        dial.abort, dial.interrupted = true, true
    end
end

local function gateEvent(e)
    local name = e[1]
    -- newer Stargate Journey versions send the peripheral name first
    local o = 2
    if type(e[2]) == "string" then
        if ifaceName and e[2] ~= ifaceName then return end
        o = 3
    end

    if name == "stargate_chevron_engaged" then
        local incoming
        for i = o, #e do
            if type(e[i]) == "boolean" then incoming = e[i] end
        end
        if incoming ~= nil then gate.incomingChevrons = incoming end
        if incoming then
            gate.outgoing = false
            interruptDial()
        end
    elseif name == "stargate_incoming_wormhole" then
        gate.outgoing = false
        interruptDial()
        gate.remote = eventAddress(e, o)
        if gate.remote and #gate.remote > 0 then gate.lastIncoming = gate.remote end
        local who = describeRemote(gate.remote)
        setMessage("Incoming wormhole" .. (who and (" from " .. who) or ""), colors.red)
    elseif name == "stargate_outgoing_wormhole" then
        gate.outgoing = true
        gate.remote = eventAddress(e, o) or gate.remote
        local who = (dial.entry and dial.active and dial.entry.name) or describeRemote(gate.remote)
        if dial.entry and dial.active then
            dial.entry.last = "ok"
            saveBook()
        end
        setMessage("Wormhole open" .. (who and (" to " .. who) or ""), colors.lightBlue)
        if db.settings.autoClose then armAutoClose(CONFIG.autoCloseIdle) end
    elseif name == "stargate_disconnected" or name == "stargate_reset" then
        disarmAutoClose()
        local code, desc = e[o], e[o + 1]
        gate.outgoing, gate.remote, gate.incomingChevrons = false, nil, false
        -- keep the dialer's own result message if the reset belongs to that dial
        if not dial.active and os.clock() - dial.endedAt > 2 and os.clock() - autoClose.closedAt > 2 then
            local text = (type(desc) == "string" and desc ~= "") and desc or (type(code) == "number" and feedbackText(code))
            if name == "stargate_disconnected" then
                setMessage("Gate closed" .. (text and (": " .. text) or ""), colors.lightGray)
            elseif type(code) == "number" and code < 0 then
                setMessage("Gate reset: " .. text, colors.red)
            end
        end
    elseif name == "stargate_deconstructing_entity" then
        if gate.state == "OPEN" and db.settings.autoClose then armAutoClose(CONFIG.autoCloseDelay) end

    -- SGCraft
    elseif name == "sgDialIn" then
        gate.outgoing, gate.incomingChevrons = false, true
        interruptDial()
        gate.remote = toAddress(e[o])
        if gate.remote then gate.lastIncoming = gate.remote end
        local who = describeRemote(gate.remote)
        setMessage("Incoming wormhole" .. (who and (" from " .. who) or ""), colors.red)
    elseif name == "sgDialOut" then
        gate.outgoing, gate.incomingChevrons = true, false
        gate.remote = toAddress(e[o]) or gate.remote
    elseif name == "sgStargateStateChange" then
        local new = e[o]
        local _, _, direction = iface.state()
        if new == "Dialling" and direction == "Incoming" and not dial.active then
            -- SGCraft 2.x sends no sgDialIn, it reports the direction instead
            gate.outgoing, gate.incomingChevrons = false, true
            gate.remote = toAddress(call("getConnectedAddress"))
            if gate.remote then gate.lastIncoming = gate.remote end
            local who = describeRemote(gate.remote)
            setMessage("Incoming wormhole" .. (who and (" from " .. who) or ""), colors.red)
        elseif new == "Connected" and gate.outgoing then
            local who = (dial.entry and dial.active and dial.entry.name) or describeRemote(gate.remote)
            setMessage("Wormhole open" .. (who and (" to " .. who) or ""), colors.lightBlue)
            if db.settings.autoClose then armAutoClose(CONFIG.autoCloseIdle) end
        elseif new == "Idle" then
            disarmAutoClose()
            gate.outgoing, gate.remote, gate.incomingChevrons = false, nil, false
            if not dial.active and os.clock() - dial.endedAt > 2 and os.clock() - autoClose.closedAt > 2 then
                setMessage("Gate closed", colors.lightGray)
            end
        end
    end
    refreshGate()
end

local function attachInterface()
    iface, ifaceName, ifaceType = findInterface()
    if iface then
        detectGate()
        refreshGate()
        -- fail safe: an already active connection is treated as incoming unless the gate says otherwise
        if gate.connected and gate.state == "OPEN" and db.settings.autoClose then armAutoClose(CONFIG.autoCloseIdle) end
    else
        gate.state = "OFFLINE"
    end
end

local function uiTask()
    draw()
    local pollTimer = os.startTimer(CONFIG.pollInterval)
    while running do
        local e = table.pack(os.pullEventRaw())
        local name = e[1]
        local redraw = true

        if name == "terminate" then
            quit()
        elseif name == "timer" then
            if e[2] == pollTimer then
                refreshGate()
                -- the gate picture animates the open wormhole and the iris
                local L = layout()
                local fast = (gateView or L.side) and gate.state ~= "IDLE" and gate.state ~= "OFFLINE"
                pollTimer = os.startTimer(fast and 0.3 or CONFIG.pollInterval)
            elseif e[2] == autoClose.timer then
                autoClose.timer, autoClose.deadline = nil, nil
                refreshGate()
                if gate.state == "OPEN" then
                    autoClose.closedAt = os.clock()
                    call("disconnectStargate")
                    setMessage("Wormhole closed by auto-close", colors.lightGray)
                end
            else
                redraw = false
            end
        elseif GATE_EVENTS[name] then
            gateEvent(e)
        elseif name == "peripheral" then
            if not iface then attachInterface() end
        elseif name == "peripheral_detach" then
            if e[2] == ifaceName then
                interruptDial()
                iface, ifaceName = nil, nil
                gate.state = "OFFLINE"
                setMessage("Stargate interface disconnected", colors.red)
            end
        elseif name == "key" or name == "key_up" then
            if name == "key" then held[e[2]] = true else held[e[2]] = nil end
            if name == "key" then
                if modal then modal.event(e) else mainEvent(e) end
            end
        elseif name == "char" and (held[keys.leftCtrl] or held[keys.rightCtrl]) then
            redraw = false -- part of a Ctrl shortcut, not typing
        elseif name == "char" or name == "paste" or name == "mouse_scroll" then
            if modal then modal.event(e) else mainEvent(e) end
        elseif name == "mouse_click" then
            click(e[3], e[4], e[2])
        elseif name == "monitor_touch" then
            if e[2] == monitorName then click(e[3], e[4], 1) else redraw = false end
        elseif name == "term_resize" or name == "monitor_resize" then
            local w, h = target.getSize()
            screen.reposition(1, 1, w, h)
            ensureVisible()
        elseif name ~= "dialer_redraw" then
            redraw = false
        end

        if running and redraw then draw() end
    end
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

loadBook()
attachInterface()
refilter()
if loadNotice then
    setMessage(loadNotice, colors.yellow)
elseif not iface then
    setMessage("No stargate interface found - attach one to dial", colors.red)
else
    setMessage("Ready - [?] or Ctrl+H for help", colors.lightGray)
end

local ok, err = pcall(parallel.waitForAny, uiTask, dialerTask)

term.redirect(native)
if monitor then
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
end
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
term.setCursorPos(1, 1)
term.setCursorBlink(false)

if not ok and err ~= "Terminated" then
    printError(err)
else
    print("Personal Dialer closed.")
end
