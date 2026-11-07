--
--   StargateNetwork
--
-- A rednet based network for every Stargate in your world.
-- Written for Stargate Journey 0.6.x + CC:Tweaked on Minecraft 1.20.1
--
-- Run it on a computer next to a Stargate interface (gate node), or on any
-- computer / pocket computer without an interface (remote control).
--
--  * finds every other gate running StargateNetwork automatically
--  * remembers gates even when their chunk is unloaded, so you can still dial them
--  * dial from a list (keyboard or mouse) or type an address by hand
--  * shows who is calling when a wormhole comes in
--  * optional auto-iris that only opens for gates in your network
--  * control any gate from a pocket computer (needs a shared network key)
--
-- Usage: sgnet          start the program
--        sgnet setup    run setup again
--

local VERSION = "1.0.0"

local args = { ... }

local pack = table.pack or function(...) return { n = select("#", ...), ... } end
local unpack = table.unpack or unpack

-- ==========================================================================
--  CONSTANTS
-- ==========================================================================

local BASE_DIR = ""
if shell and shell.getRunningProgram then
    BASE_DIR = fs.getDir(shell.getRunningProgram())
end

local CONFIG_FILE = fs.combine(BASE_DIR, "sgnet.cfg")
local DIRECTORY_FILE = fs.combine(BASE_DIR, "sgnet_dir.dat")

local PROTOCOL_PREFIX = "sgnet:"
local MSG_VERSION = 1
local HEARTBEAT_EVERY = 15  -- seconds between announcements
local OFFLINE_AFTER = 45    -- seconds without announcement before a gate is "offline"
local MAX_SYMBOL = 38
local MAX_NAME = 20
local MAX_LOG = 60

local INTERFACE_TYPES = { "advanced_crystal_interface", "crystal_interface", "basic_interface" }

local STATUSES = { IDLE = true, DIALING = true, INCOMING = true, OUTGOING = true }
local IRIS_STATES = { OPEN = true, CLOSED = true, MOVING = true, NONE = true }

-- fallback descriptions when the interface does not give us a message
local FEEDBACK = {
    [0] = "No feedback",
    [-1] = "Unknown error",
    [1] = "Symbol encoded",
    [-2] = "Symbol already in address",
    [-3] = "Symbol out of bounds",
    [2] = "Connection established (system wide)",
    [3] = "Connection established (interstellar)",
    [4] = "Connection established (intergalactic)",
    [-4] = "Incomplete address",
    [-5] = "Invalid address",
    [-6] = "Not enough power",
    [-7] = "Self obstructed",
    [-8] = "Target obstructed",
    [-9] = "Cannot dial itself",
    [-10] = "Same system dial",
    [-11] = "Already connected",
    [-12] = "No galaxy",
    [-13] = "No dimensions",
    [-14] = "No stargates",
    [7] = "Connection ended by disconnect",
    [8] = "Connection ended by point of origin",
    [9] = "Connection ended by network",
    [10] = "Connection ended by autoclose",
    [11] = "Chevron raised",
    [12] = "Rotating",
    [13] = "Rotation stopped",
    [-24] = "Rotation blocked",
    [-25] = "Not rotating",
    [-26] = "Chevron already raised",
    [-27] = "Chevron already lowered",
    [-28] = "Chevron not raised",
    [-29] = "Cannot encode point of origin",
}

-- ==========================================================================
--  SMALL HELPERS
-- ==========================================================================

local function trim(s)
    return (tostring(s):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- returns a printable string of at most n characters, or nil for non strings
local function cleanString(s, n)
    if type(s) ~= "string" then return nil end
    s = s:gsub("%c", "")
    if #s > n then s = s:sub(1, n) end
    return trim(s)
end

local function clip(s, n)
    s = tostring(s)
    if n <= 0 then return "" end
    if #s > n then return s:sub(1, n) end
    return s
end

local function pad(s, n)
    s = clip(s, n)
    return s .. string.rep(" ", n - #s)
end

local function padLeft(s, n)
    s = clip(s, n)
    return string.rep(" ", n - #s) .. s
end

local function deepCopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = deepCopy(x) end
    return out
end

-- Validates an address received from the network, a file or the gate.
-- Returns a copy without the point of origin, or nil.
local function sanitizeAddress(a)
    if type(a) ~= "table" then return nil end
    local out = {}
    for i = 1, 9 do
        local s = a[i]
        if s == nil then break end
        if type(s) ~= "number" or s ~= math.floor(s) or s < 0 or s > MAX_SYMBOL then
            return nil
        end
        out[#out + 1] = s
    end
    if out[#out] == 0 then out[#out] = nil end
    if #out == 0 then return nil end
    for _, s in ipairs(out) do
        if s == 0 then return nil end
    end
    return out
end

-- a dialable address: 6 to 8 symbols (7, 8 or 9 chevrons with the point of origin)
local function dialable(a)
    a = sanitizeAddress(a)
    if a and #a >= 6 and #a <= 8 then return a end
    return nil
end

-- Parses "26-6-14-31-11-29", "26 6 14 31 11 29" or "-26-6-14-31-11-29-0-"
local function parseAddress(text)
    local addr = {}
    for num in tostring(text):gmatch("%d+") do
        addr[#addr + 1] = tonumber(num)
    end
    if addr[#addr] == 0 then addr[#addr] = nil end

    if #addr < 6 or #addr > 8 then
        return nil, "An address needs 6 to 8 symbols (got " .. #addr .. ")"
    end
    local seen = {}
    for _, s in ipairs(addr) do
        if s < 1 or s > MAX_SYMBOL then
            return nil, "Symbols must be between 1 and " .. MAX_SYMBOL
        end
        if seen[s] then
            return nil, "Symbol " .. s .. " is used twice"
        end
        seen[s] = true
    end
    return addr
end

local function addrToString(addr)
    if not addr or #addr == 0 then return "-" end
    return "-" .. table.concat(addr, "-") .. "-"
end

local function addrEq(a, b)
    if not a or not b or #a ~= #b then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

local function addrIn(addr, list)
    for _, x in ipairs(list or {}) do
        if addrEq(addr, x) then return true end
    end
    return false
end

local function formatEnergy(n)
    if type(n) ~= "number" then return nil end
    local units = { { 1e12, "T" }, { 1e9, "G" }, { 1e6, "M" }, { 1e3, "k" } }
    for _, u in ipairs(units) do
        if n >= u[1] then
            return string.format("%.1f%sFE", n / u[1], u[2])
        end
    end
    return string.format("%dFE", math.floor(n))
end

-- "sgjourney:milky_way_stargate" -> "MilkyWay"
local function shortType(t)
    if type(t) ~= "string" then return nil end
    t = t:gsub("^.*:", ""):gsub("_stargate$", "")
    local out = t:gsub("_(%a)", function(c) return c:upper() end):gsub("^%a", string.upper)
    return clip(out, 12)
end

local function formatAgo(seconds)
    seconds = math.max(0, math.floor(seconds))
    if seconds < 60 then return seconds .. "s ago" end
    if seconds < 3600 then return math.floor(seconds / 60) .. "m ago" end
    return math.floor(seconds / 3600) .. "h ago"
end

local function loadTable(path)
    if not fs.exists(path) then return nil end
    local f = fs.open(path, "r")
    if not f then return nil end
    local data = f.readAll()
    f.close()
    local ok, t = pcall(textutils.unserialize, data)
    if ok and type(t) == "table" then return t end
    return nil
end

local function saveTable(path, t)
    local f = fs.open(path, "w")
    if not f then return false end
    f.write(textutils.serialize(t))
    f.close()
    return true
end

-- ==========================================================================
--  CONFIGURATION
-- ==========================================================================

local DEFAULT_CONFIG = {
    name = nil,             -- name of this gate shown to the network
    network = "default",    -- gates only see other gates in the same network
    key = "",               -- shared secret for remote control (blank = disabled)
    allowRemote = true,     -- let other computers with the key dial/close this gate
    autoIris = false,       -- close the iris on incoming wormholes ...
    trustNetwork = true,    -- ... but open it for gates from this network
    fastDial = false,       -- Milky Way: skip ring rotation if the interface allows it
    showNetworkLog = true,  -- show what other gates are doing in the log
    address = nil,          -- override the address others should dial (nil = auto)
    aliases = {},           -- other addresses of this gate, used to recognise callers
    book = {                -- address book, edit freely
        { name = "Abydos", address = { 26, 6, 14, 31, 11, 29 } },
        { name = "Chulak", address = { 8, 1, 22, 14, 36, 19 } },
        { name = "Lantea", address = { 18, 20, 1, 15, 14, 7, 19 } },
    },
}

local cfg
local firstRun = false

local function sanitizeConfig(c)
    for k, v in pairs(DEFAULT_CONFIG) do
        if c[k] == nil then c[k] = deepCopy(v) end
    end

    c.name = cleanString(c.name, MAX_NAME)
    if c.name == "" then c.name = nil end
    c.network = cleanString(c.network, 16) or "default"
    c.network = c.network:gsub("[^%w_%-]", "")
    if c.network == "" then c.network = "default" end
    c.key = cleanString(c.key, 64) or ""

    if type(c.address) == "string" then
        c.address = parseAddress(c.address)
    else
        c.address = dialable(c.address)
    end

    local aliases = {}
    for _, a in ipairs(type(c.aliases) == "table" and c.aliases or {}) do
        local s = type(a) == "string" and parseAddress(a) or dialable(a)
        if s then aliases[#aliases + 1] = s end
    end
    c.aliases = aliases

    local book = {}
    for _, b in ipairs(type(c.book) == "table" and c.book or {}) do
        if type(b) == "table" then
            local addr = type(b.address) == "string" and parseAddress(b.address) or dialable(b.address)
            local name = cleanString(b.name, MAX_NAME)
            if addr then
                book[#book + 1] = { name = (name and name ~= "") and name or addrToString(addr), address = addr }
            end
        end
    end
    c.book = book

    for _, k in ipairs({ "allowRemote", "autoIris", "trustNetwork", "fastDial", "showNetworkLog" }) do
        c[k] = c[k] == true
    end
    return c
end

local function loadConfig()
    local c = loadTable(CONFIG_FILE)
    if not c then
        firstRun = true
        c = {}
    end
    cfg = sanitizeConfig(c)
end

local function saveConfig()
    saveTable(CONFIG_FILE, cfg)
end

-- ==========================================================================
--  PERIPHERALS
-- ==========================================================================

local iface, ifaceName, ifaceType
for _, t in ipairs(INTERFACE_TYPES) do
    local p = peripheral.find(t)
    if p then
        iface, ifaceName, ifaceType = p, peripheral.getName(p), t
        break
    end
end

local modemName
do
    local wireless = peripheral.find("modem", function(_, m) return m.isWireless() end)
    local any = wireless or peripheral.find("modem")
    if any then modemName = peripheral.getName(any) end
end

local function has(method)
    return iface ~= nil and type(iface[method]) == "function"
end

-- calls an interface method, never throws; missing methods return nil
local function call(method, ...)
    if not has(method) then return nil end
    local res = pack(pcall(iface[method], ...))
    if not res[1] then return nil end
    return unpack(res, 2, res.n)
end

local function describeFeedback(code)
    if type(code) ~= "number" then return "unknown feedback" end
    local recent, message = call("getRecentFeedback")
    if recent == code and type(message) == "string" and message ~= "" then
        if not message:find(" ") then
            -- turn "message.sgjourney.stargate.error.self_obstructed" into "Self obstructed"
            message = message:gsub("^.*%.", ""):gsub("_", " ")
        end
        if message ~= "" then
            return (message:gsub("^%l", string.upper))
        end
    end
    return FEEDBACK[code] or ("feedback " .. code)
end

local function isError(code)
    return type(code) == "number" and code < 0
end

-- ==========================================================================
--  STATE
-- ==========================================================================

local myId = os.getComputerID()
local isColor = term.isColor()

local state = {
    mode = iface and "gate" or "remote",
    status = "IDLE",
    chevrons = 0,
    energy = nil,
    gtype = nil,
    address = nil,
    iris = nil,
    target = nil,           -- address we are dialing / connected to
    outTarget = nil,        -- address reported by the outgoing wormhole event
    peer = nil,             -- readable name of the other side
    outgoing = nil,         -- true/false once we saw a wormhole event
    incomingDial = false,   -- incoming chevrons are lighting up
    inWormhole = false,     -- incoming wormhole is active
    caller = nil,
    callerAddr = nil,
    callerTrusted = false,
    irisAutoClosed = false,
    controlId = nil,        -- nil = this computer's own gate, number = remote gate
    selKey = nil,
    scroll = 0,
    modal = false,
    started = false,
    signature = "",
}

local directory = {}   -- [computer id] = gate entry
local logLines = {}

local requestRedraw -- forward declaration

local function log(text, color)
    local time = textutils.formatTime(os.time(), true)
    if #time < 5 then time = " " .. time end
    table.insert(logLines, { time = time, text = tostring(text), color = color or colors.white })
    while #logLines > MAX_LOG do table.remove(logLines, 1) end
    if requestRedraw then requestRedraw() end
end

local function isOnline(e)
    return e.lastSeen ~= nil and (os.clock() - e.lastSeen) <= OFFLINE_AFTER
end

local function saveDirectory()
    local out = {}
    for id, e in pairs(directory) do
        out[id] = { name = e.name, address = e.address, aliases = e.aliases, gtype = e.gtype, remote = e.remote }
    end
    saveTable(DIRECTORY_FILE, out)
end

local function loadDirectory()
    local t = loadTable(DIRECTORY_FILE) or {}
    for id, e in pairs(t) do
        if type(id) == "number" and type(e) == "table" and id ~= myId then
            directory[id] = {
                id = id,
                name = cleanString(e.name, MAX_NAME) or ("Gate #" .. id),
                address = sanitizeAddress(e.address),
                aliases = {},
                gtype = cleanString(e.gtype, 12),
                remote = e.remote == true,
                status = "OFFLINE",
            }
            for _, a in ipairs(type(e.aliases) == "table" and e.aliases or {}) do
                local s = sanitizeAddress(a)
                if s then table.insert(directory[id].aliases, s) end
            end
        end
    end
end

-- readable name for an address (network gate, address book or the raw address)
local function labelFor(addr)
    if not addr then return "unknown" end
    if state.address and addrEq(addr, state.address) then return cfg.name or "this gate" end
    for _, e in pairs(directory) do
        if addrEq(e.address, addr) or addrIn(addr, e.aliases) then return e.name end
    end
    for _, b in ipairs(cfg.book) do
        if addrEq(b.address, addr) then return b.name end
    end
    return addrToString(addr)
end

local function myAddresses()
    local list = {}
    if state.address then list[#list + 1] = state.address end
    for _, a in ipairs(cfg.aliases) do list[#list + 1] = a end
    return list
end

-- ==========================================================================
--  NETWORK
-- ==========================================================================

local protocol

local function netSend(id, msg)
    if not modemName then return end
    msg.v = MSG_VERSION
    rednet.send(id, msg, protocol)
end

local function netBroadcast(msg)
    if not modemName then return end
    msg.v = MSG_VERSION
    rednet.broadcast(msg, protocol)
end

local function broadcastLog(text)
    netBroadcast({ type = "log", text = text })
end

local function buildAnnounce()
    return {
        type = "announce",
        gate = {
            name = cfg.name,
            address = state.address,
            aliases = cfg.aliases,
            gtype = state.gtype,
            status = state.status,
            energy = state.energy,
            iris = state.iris,
            target = state.target,
            peer = state.peer,
            remote = cfg.allowRemote and cfg.key ~= "",
        },
    }
end

local function announce()
    if state.mode == "gate" then netBroadcast(buildAnnounce()) end
end

-- ==========================================================================
--  LOCAL GATE
-- ==========================================================================

local Dialer = { busy = false, abort = false, job = nil, target = nil }

local function irisState()
    if not has("closeIris") then return nil end
    if has("getIris") then
        local item = call("getIris")
        if item == nil or item == false or item == "" then return "NONE" end
    end
    local pct = call("getIrisProgressPercentage")
    if type(pct) == "number" then
        if pct <= 0 then return "OPEN" end
        if pct >= 100 then return "CLOSED" end
        return "MOVING"
    end
    -- no way to read the iris, best guess is the last command we gave
    return state.lastIrisCmd == "close" and "CLOSED" or "OPEN"
end

local function hasIris()
    local st = irisState()
    return st ~= nil and st ~= "NONE"
end

local function readLocalAddress()
    if cfg.address then return cfg.address end
    return sanitizeAddress(call("getLocalAddress"))
end

-- reads the gate and returns true when something worth announcing changed
local function refreshLocal()
    if not iface then return false end

    local connected = call("isStargateConnected") == true
    local chevrons = call("getChevronsEngaged") or 0
    local status

    if connected then
        local out = call("isStargateDialingOut")
        if type(out) ~= "boolean" then out = state.outgoing end
        -- when unsure treat the wormhole as incoming, it is the safe option
        status = out and "OUTGOING" or "INCOMING"
    elseif state.incomingDial and not Dialer.busy and chevrons > 0 then
        status = "INCOMING"
    elseif Dialer.busy or chevrons > 0 then
        status = "DIALING"
    else
        status = "IDLE"
    end

    local target, peer
    if status == "DIALING" or status == "OUTGOING" then
        target = Dialer.target or state.outTarget
            or sanitizeAddress(call("getConnectedAddress"))
            or sanitizeAddress(call("getDialedAddress"))
        peer = target and labelFor(target) or nil
    elseif status == "INCOMING" then
        peer = state.caller
        if not peer and connected then
            local a = sanitizeAddress(call("getConnectedAddress"))
            peer = a and labelFor(a) or "unknown gate"
        end
    end

    state.status = status
    state.chevrons = chevrons
    state.target = target
    state.peer = peer
    state.energy = call("getStargateEnergy") or call("getEnergy")
    state.iris = irisState()
    if not state.address then state.address = readLocalAddress() end

    local sig = table.concat({ status, chevrons, tostring(state.iris), addrToString(target), tostring(peer) }, "|")
    local changed = sig ~= state.signature
    state.signature = sig
    return changed
end

-- ==========================================================================
--  IRIS
-- ==========================================================================

local function setIris(mode)
    if not has("closeIris") then return false, "This interface has no iris control" end
    local st = irisState()
    if st == "NONE" then return false, "No iris installed" end

    if mode == "toggle" then
        if st == "OPEN" or (st ~= "CLOSED" and state.lastIrisCmd == "open") then
            mode = "close"
        else
            mode = "open"
        end
    end

    if mode == "close" then
        call("closeIris")
    else
        call("openIris")
        state.irisAutoClosed = false
    end
    state.lastIrisCmd = mode
    return true, mode
end

-- closes the iris for unknown callers, opens it for gates from our network
local function applyIrisPolicy()
    if not cfg.autoIris or not hasIris() then return end

    if state.callerTrusted and cfg.trustNetwork then
        if irisState() ~= "OPEN" then
            call("openIris")
            log("Auto-iris: opened for " .. tostring(state.caller), colors.lime)
        end
    elseif irisState() ~= "CLOSED" then
        call("closeIris")
        state.irisAutoClosed = true
        log("Auto-iris: closing", colors.yellow)
    end
end

-- ==========================================================================
--  CALLER IDENTIFICATION
-- ==========================================================================

-- returns the network gate that is calling us, if we can tell
local function identifyCaller(callerAddr)
    if callerAddr then
        for _, e in pairs(directory) do
            if addrEq(e.address, callerAddr) or addrIn(callerAddr, e.aliases) then
                return e
            end
        end
    end
    local mine = myAddresses()
    for _, e in pairs(directory) do
        if isOnline(e) and e.target and (e.status == "DIALING" or e.status == "OUTGOING")
            and addrIn(e.target, mine) then
            return e
        end
    end
    return nil
end

local function setCaller(e, callerAddr)
    if e then
        state.caller = e.name
        state.callerTrusted = true
    else
        state.caller = callerAddr and labelFor(callerAddr) or "unknown gate"
        state.callerTrusted = false
    end
end

-- ==========================================================================
--  DIALING
-- ==========================================================================

local function checkAbort()
    if Dialer.abort then error("__abort", 0) end
end

local function waitFor(fn, timeout, what)
    local deadline = os.clock() + timeout
    while true do
        checkAbort()
        if fn() then return end
        if os.clock() > deadline then error("Timed out waiting for " .. what, 0) end
        sleep(0.1)
    end
end

local function pause(t)
    sleep(t)
    checkAbort()
end

local function fail(code)
    error(describeFeedback(code), 0)
end

local function prepareGate()
    call("endRotation")
    if call("isChevronOpen") == true then
        call("closeChevron")
    end
    if (call("getChevronsEngaged") or 0) > 0 and not call("isStargateConnected") then
        call("disconnectStargate")
        pause(1)
    end
end

-- Milky Way ring: rotate, raise and lower the chevron
local function engageRotating(symbol, i)
    if i % 2 == 0 then
        call("rotateClockwise", symbol)
    else
        call("rotateAntiClockwise", symbol)
    end
    waitFor(function() return call("isCurrentSymbol", symbol) == true end, 60, "ring rotation")
    pause(0.5)

    local fb = call("openChevron")
    if isError(fb) and fb ~= -26 then fail(fb) end
    pause(0.6)

    fb = call("closeChevron")
    if isError(fb) and fb ~= -27 then fail(fb) end
    pause(0.4)
end

-- every other gate (and Milky Way through a crystal interface)
local function engageDirect(symbol, i)
    local fb = call("engageSymbol", symbol)
    if isError(fb) then fail(fb) end

    waitFor(function()
        if call("isStargateConnected") then return true end
        local c = call("getChevronsEngaged") or 0
        if c < i - 1 then
            local code = call("getRecentFeedback")
            error("Gate reset: " .. describeFeedback(code), 0)
        end
        return c >= i
    end, 45, "chevron " .. i)
end

local function performDial(addr)
    local full = {}
    for _, s in ipairs(addr) do full[#full + 1] = s end
    full[#full + 1] = 0

    prepareGate()

    local rotate = has("rotateClockwise") and (not cfg.fastDial or not has("engageSymbol"))
    if not rotate and not has("engageSymbol") then
        error("This interface cannot dial this gate", 0)
    end

    for i, symbol in ipairs(full) do
        checkAbort()
        if rotate then
            engageRotating(symbol, i)
        else
            engageDirect(symbol, i)
        end
    end

    waitFor(function()
        if call("isStargateConnected") then return true end
        if (call("getChevronsEngaged") or 0) == 0 then
            local code = call("getRecentFeedback")
            error(describeFeedback(code), 0)
        end
        return false
    end, 20, "wormhole")
end

local function requestDial(addr)
    if not iface then return false, "No stargate interface on this computer" end
    if Dialer.busy or Dialer.job then return false, "Already dialing" end
    if state.status == "OUTGOING" or state.status == "INCOMING" then
        return false, "Wormhole active - close it first"
    end
    if state.address and addrEq(addr, state.address) then
        return false, "That is this gate's own address"
    end
    Dialer.job = { address = addr }
    os.queueEvent("sgnet_dial")
    return true
end

local function requestDisconnect()
    if not iface then return false, "No stargate interface on this computer" end
    if Dialer.busy then Dialer.abort = true end
    call("endRotation")
    local fb = call("disconnectStargate")
    if isError(fb) then
        return false, describeFeedback(fb)
    end
    return true
end

local function dialWorker()
    while true do
        os.pullEvent("sgnet_dial")
        local job = Dialer.job
        Dialer.job = nil
        if job then
            local label = labelFor(job.address)
            Dialer.busy, Dialer.abort, Dialer.target = true, false, job.address
            log("Dialing " .. label .. " " .. addrToString(job.address), colors.orange)
            broadcastLog((cfg.name or "?") .. " is dialing " .. label)
            if refreshLocal() then announce() end
            requestRedraw()

            local ok, err = pcall(performDial, job.address)
            Dialer.busy = false
            if not ok then
                Dialer.target = nil
                if err == "__abort" then
                    log("Dialing aborted", colors.yellow)
                else
                    log("Dialing failed: " .. tostring(err), colors.red)
                    call("endRotation")
                    if not call("isStargateConnected") then call("disconnectStargate") end
                end
            end
            if refreshLocal() then announce() end
            requestRedraw()
        end
    end
end

-- ==========================================================================
--  GATE EVENTS
-- ==========================================================================

local function onIncomingDialStart()
    state.incomingDial = true
    log("Incoming dialing sequence!", colors.orange)
    if cfg.autoIris and hasIris() and irisState() ~= "CLOSED" then
        call("closeIris")
        state.irisAutoClosed = true
        log("Auto-iris: closing", colors.yellow)
    end
end

local function onIncomingWormhole(addr)
    state.incomingDial = true
    state.inWormhole = true
    state.outgoing = false
    state.callerAddr = addr
    setCaller(identifyCaller(addr), addr)
    local trust = state.callerTrusted and " (network gate)" or ""
    log("Incoming wormhole from " .. state.caller .. trust, colors.red)
    applyIrisPolicy()
end

local function onOutgoingWormhole(addr)
    state.outgoing = true
    state.outTarget = Dialer.target or addr
    local label = labelFor(state.outTarget or state.target)
    log("Wormhole established to " .. label, colors.lightBlue)
    broadcastLog((cfg.name or "?") .. " -> " .. label .. ": wormhole open")
    if cfg.autoIris and hasIris() and irisState() ~= "OPEN" then
        call("openIris")
        log("Auto-iris: opening for outgoing travel", colors.lime)
    end
end

local function onDisconnect(feedback, eventName)
    local wasActive = state.inWormhole or state.outgoing or state.status ~= "IDLE"
    if wasActive and not Dialer.busy then
        local what = eventName == "stargate_reset" and "Gate reset" or "Wormhole closed"
        local why = type(feedback) == "number" and (": " .. describeFeedback(feedback)) or ""
        log(what .. why, colors.lightGray)
        if state.outgoing then broadcastLog((cfg.name or "?") .. ": wormhole closed") end
    end

    state.incomingDial = false
    state.inWormhole = false
    state.outgoing = nil
    state.caller = nil
    state.callerAddr = nil
    state.callerTrusted = false
    state.outTarget = nil
    if not Dialer.busy then
        Dialer.target = nil
    end

    if cfg.autoIris and state.irisAutoClosed and hasIris() then
        call("openIris")
        log("Auto-iris: reopening", colors.lime)
    end
    state.irisAutoClosed = false
end

local function handleGateEvent(ev)
    local name = ev[1]
    if name == "stargate_chevron_engaged" then
        local incoming
        if ev.n >= 6 then incoming = ev[5] else incoming = ev[4] end
        if incoming == true and not state.incomingDial then onIncomingDialStart() end
    elseif name == "stargate_incoming_wormhole" then
        onIncomingWormhole(sanitizeAddress(ev[3]))
    elseif name == "stargate_outgoing_wormhole" then
        onOutgoingWormhole(sanitizeAddress(ev[3]))
    elseif name == "stargate_disconnected" or name == "stargate_reset" then
        onDisconnect(ev[3], name)
    elseif name == "stargate_message_received" then
        log("Message: " .. (cleanString(ev[3], 60) or "?"), colors.yellow)
    elseif name == "stargate_reconstructing_entity" then
        local who = cleanString(ev[4], 30)
        if who then log(who .. " came through the gate", colors.lightGray) end
    end

    if refreshLocal() then announce() end
    requestRedraw()
end

-- ==========================================================================
--  NETWORK MESSAGES
-- ==========================================================================

local function updateEntry(sender, g)
    if type(g) ~= "table" then return end
    if type(g.name) ~= "string" and not sanitizeAddress(g.address) then return end

    local e = directory[sender]
    local isNew = e == nil
    if isNew then
        e = { id = sender }
        directory[sender] = e
    end

    local oldName, oldAddr, oldRemote = e.name, e.address, e.remote
    e.name = cleanString(g.name, MAX_NAME) or ("Gate #" .. sender)
    if e.name == "" then e.name = "Gate #" .. sender end
    e.address = sanitizeAddress(g.address)
    e.aliases = {}
    if type(g.aliases) == "table" then
        for i = 1, math.min(#g.aliases, 4) do
            local a = sanitizeAddress(g.aliases[i])
            if a then e.aliases[#e.aliases + 1] = a end
        end
    end
    e.gtype = cleanString(shortType(g.gtype) or g.gtype, 12)
    e.status = STATUSES[g.status] and g.status or "IDLE"
    e.energy = type(g.energy) == "number" and g.energy or nil
    e.iris = IRIS_STATES[g.iris] and g.iris or nil
    e.target = sanitizeAddress(g.target)
    e.peer = cleanString(g.peer, 30)
    e.remote = g.remote == true
    local wasOnline = e.lastSeen ~= nil and isOnline(e)
    e.lastSeen = os.clock()

    if isNew then
        log("New gate joined: " .. e.name, colors.lime)
    elseif not wasOnline then
        log(e.name .. " is online", colors.lime)
    end

    if isNew or oldName ~= e.name or not addrEq(oldAddr, e.address) or oldRemote ~= e.remote then
        saveDirectory()
    end

    -- remote computers pick the first gate they can control
    if state.mode == "remote" and state.controlId == nil and e.remote then
        state.controlId = sender
        log("Controlling " .. e.name .. " (press G to switch)", colors.lightBlue)
    end

    -- maybe this gate is the one calling us
    if state.inWormhole and not state.callerTrusted then
        local caller = identifyCaller(state.callerAddr)
        if caller then
            setCaller(caller, state.callerAddr)
            log("Caller identified: " .. caller.name, colors.lime)
            applyIrisPolicy()
            if refreshLocal() then announce() end
        end
    end
end

local function handleCommand(sender, msg)
    if state.mode ~= "gate" then return end

    local function reply(ok, text)
        netSend(sender, { type = "result", req = msg.req, ok = ok, text = text, name = cfg.name })
    end

    if not cfg.allowRemote or cfg.key == "" then
        return reply(false, "Remote control is disabled")
    end
    if msg.key ~= cfg.key then
        log("Rejected command from computer #" .. sender .. " (wrong key)", colors.red)
        return reply(false, "Access denied (wrong key)")
    end

    local who = cleanString(msg.from, MAX_NAME) or ("computer #" .. sender)

    if msg.action == "dial" then
        local addr = dialable(msg.address)
        if not addr then return reply(false, "Invalid address") end
        local ok, err = requestDial(addr)
        if ok then log(who .. " remotely dialed " .. labelFor(addr), colors.lightBlue) end
        return reply(ok, ok and ("Dialing " .. labelFor(addr)) or err)
    elseif msg.action == "disconnect" then
        local ok, err = requestDisconnect()
        log(who .. " remotely closed the gate", colors.lightBlue)
        return reply(ok, ok and "Gate closed" or err)
    elseif msg.action == "iris" then
        local mode = msg.mode
        if mode ~= "open" and mode ~= "close" and mode ~= "toggle" then
            return reply(false, "Unknown iris command")
        end
        local ok, result = setIris(mode)
        if ok then log(who .. " remotely set iris: " .. result, colors.lightBlue) end
        return reply(ok, ok and ("Iris " .. result) or result)
    end
    reply(false, "Unknown command")
end

local function onMessage(sender, msg)
    if type(msg) ~= "table" or msg.v ~= MSG_VERSION or sender == myId then return end

    local t = msg.type
    if t == "hello" then
        if state.mode == "gate" then netSend(sender, buildAnnounce()) end
    elseif t == "announce" then
        updateEntry(sender, msg.gate)
    elseif t == "bye" then
        local e = directory[sender]
        if e and e.lastSeen then
            e.lastSeen = nil
            log(e.name .. " left the network", colors.gray)
        end
    elseif t == "log" then
        local text = cleanString(msg.text, 80)
        if cfg.showNetworkLog and text then log(text, colors.lightGray) end
    elseif t == "cmd" then
        handleCommand(sender, msg)
    elseif t == "result" then
        local name = cleanString(msg.name, MAX_NAME) or ("#" .. sender)
        local text = cleanString(msg.text, 60) or ""
        log(name .. ": " .. text, msg.ok and colors.lime or colors.red)
    end
    requestRedraw()
end

-- ==========================================================================
--  CONTROL (local gate or a remote one)
-- ==========================================================================

local function controlledGate()
    if state.controlId ~= nil then
        local e = directory[state.controlId]
        if e then
            return {
                name = e.name, id = e.id, isRemote = true,
                status = isOnline(e) and e.status or "OFFLINE",
                iris = e.iris, energy = e.energy, address = e.address, peer = e.peer,
            }
        end
        state.controlId = nil
    end
    if not iface then return nil end
    return {
        name = cfg.name or "This gate", isRemote = false,
        status = state.status, iris = state.iris, energy = state.energy,
        address = state.address, peer = state.peer,
    }
end

local function sendCommand(payload)
    local e = directory[state.controlId]
    if not e then return end
    if not modemName then
        log("No modem attached", colors.red)
        return
    end
    if cfg.key == "" then
        log("Set a network key first (press S)", colors.red)
        return
    end
    if not e.remote then
        log(e.name .. " does not accept remote control", colors.red)
        return
    end
    payload.type = "cmd"
    payload.key = cfg.key
    payload.req = math.random(1, 1073741823)
    payload.from = cfg.name or os.getComputerLabel() or ("Computer #" .. myId)
    netSend(e.id, payload)
    log("Sent " .. payload.action .. " to " .. e.name, colors.lightGray)
end

local function dialTo(addr)
    local ctl = controlledGate()
    if not ctl then
        log("No gate to control - press G", colors.red)
        return
    end
    if ctl.address and addrEq(ctl.address, addr) then
        log("A gate cannot dial itself", colors.red)
        return
    end
    if ctl.isRemote then
        sendCommand({ action = "dial", address = addr })
    else
        local ok, err = requestDial(addr)
        if not ok then log(err, colors.red) end
    end
end

local function disconnectControlled()
    local ctl = controlledGate()
    if not ctl then
        log("No gate to control - press G", colors.red)
    elseif ctl.isRemote then
        sendCommand({ action = "disconnect" })
    else
        local ok, err = requestDisconnect()
        if ok then log("Closing gate", colors.lightGray) else log(err, colors.red) end
        if refreshLocal() then announce() end
    end
end

local function toggleIrisControlled()
    local ctl = controlledGate()
    if not ctl then
        log("No gate to control - press G", colors.red)
    elseif ctl.isRemote then
        sendCommand({ action = "iris", mode = "toggle" })
    else
        local ok, result = setIris("toggle")
        if ok then log("Iris: " .. result, colors.lightGray) else log(result, colors.red) end
        if refreshLocal() then announce() end
    end
end

local function sortedGates()
    local gates = {}
    for _, e in pairs(directory) do gates[#gates + 1] = e end
    table.sort(gates, function(a, b)
        local ao, bo = isOnline(a), isOnline(b)
        if ao ~= bo then return ao end
        local an, bn = a.name:lower(), b.name:lower()
        if an ~= bn then return an < bn end
        return a.id < b.id
    end)
    return gates
end

local function cycleControl()
    local candidates = {}
    if iface then candidates[#candidates + 1] = false end
    for _, e in ipairs(sortedGates()) do
        if e.remote and isOnline(e) then candidates[#candidates + 1] = e.id end
    end
    if #candidates == 0 or (#candidates == 1 and candidates[1] == false) then
        log("No other gate accepts remote control", colors.red)
        log("(they need the same network key)", colors.gray)
        if iface then state.controlId = nil end
        return
    end

    local current = state.controlId or false
    local index = 0
    for i, c in ipairs(candidates) do
        if c == current then index = i end
    end
    local nextId = candidates[index % #candidates + 1]
    state.controlId = nextId or nil
    local ctl = controlledGate()
    log("Now controlling " .. (ctl and ctl.name or "?"), colors.lightBlue)
end

-- ==========================================================================
--  USER INTERFACE
-- ==========================================================================

local native = term.current()
local win

local P = {
    headerBg = isColor and colors.blue or colors.gray,
    headerFg = colors.white,
    headerDim = isColor and colors.lightBlue or colors.lightGray,
    barBg = colors.gray,
    barFg = colors.lightGray,
    selBg = isColor and colors.lightGray or colors.gray,
    selFg = isColor and colors.black or colors.white,
    text = colors.white,
    dim = colors.lightGray,
}

local STATUS_COLOR = {
    IDLE = isColor and colors.lime or colors.white,
    DIALING = isColor and colors.orange or colors.white,
    INCOMING = isColor and colors.red or colors.white,
    OUTGOING = isColor and colors.lightBlue or colors.white,
    OFFLINE = colors.gray,
}

local function color(c)
    if isColor then return c end
    if c == colors.gray or c == colors.lightGray or c == colors.black then return c end
    return colors.white
end

local function writeAt(x, y, text, fg, bg)
    term.setCursorPos(x, y)
    if fg then term.setTextColor(color(fg)) end
    if bg then term.setBackgroundColor(color(bg)) end
    term.write(text)
end

local function fillLine(y, bg)
    term.setCursorPos(1, y)
    term.setBackgroundColor(color(bg))
    term.clearLine()
end

local function buildItems()
    local items = {}
    for _, e in ipairs(sortedGates()) do
        items[#items + 1] = { key = "g:" .. e.id, kind = "gate", entry = e, name = e.name, address = e.address }
    end
    for i, b in ipairs(cfg.book) do
        items[#items + 1] = { key = "b:" .. i, kind = "book", index = i, name = b.name, address = b.address }
    end
    return items
end

local function layout()
    local w, h = term.getSize()
    local logRows = h >= 16 and 3 or 2
    local listTop = 5
    local footer = h
    local logTop = footer - logRows
    local detail = logTop - 1
    local listRows = math.max(1, detail - listTop)
    return { w = w, h = h, listTop = listTop, listRows = listRows, detail = detail, logTop = logTop, logRows = logRows, footer = footer }
end

local function selectedIndex(items)
    for i, it in ipairs(items) do
        if it.key == state.selKey then return i end
    end
    if #items > 0 then
        state.selKey = items[1].key
        return 1
    end
    return 0
end

local function ensureVisible(index, rows)
    if index <= state.scroll then state.scroll = index - 1 end
    if index > state.scroll + rows then state.scroll = index - rows end
    if state.scroll < 0 then state.scroll = 0 end
end

local function connectionLine(ctl)
    if not ctl then
        if not modemName then return "No modem - attach a wireless/ender modem", colors.red end
        if cfg.key == "" then return "Remote mode: set a network key (S)", colors.yellow end
        return "Remote mode: waiting for gates...", colors.lightGray
    end
    local st = ctl.status
    if st == "DIALING" then
        return "Dialing " .. (ctl.peer or "..."), colors.orange
    elseif st == "OUTGOING" then
        return ">> Connected to " .. (ctl.peer or "?"), colors.lightBlue
    elseif st == "INCOMING" then
        return "<< Incoming from " .. (ctl.peer or "unknown gate"), colors.red
    elseif st == "OFFLINE" then
        return "Computer offline, gate may still be dialable", colors.gray
    end
    if ctl.address then return "Address " .. addrToString(ctl.address), colors.lightGray end
    return "Address unknown (set it in setup)", colors.gray
end

local function footerText(w)
    if w >= 51 then return "Ent:Dial M:Addr D:Close I:Iris G:Gate H:Help Q:Quit" end
    if w >= 38 then return "Ent:Dial M:Addr D:Close G:Gate H:Help" end
    return "Ent:Dial D:Close H:Help"
end

local function draw()
    local L = layout()
    local w = L.w
    local items = buildItems()
    local sel = selectedIndex(items)
    ensureVisible(math.max(sel, 1), L.listRows)

    if win then win.setVisible(false) end
    term.setBackgroundColor(colors.black)
    term.clear()

    -- header
    fillLine(1, P.headerBg)
    writeAt(2, 1, "StargateNetwork", P.headerFg, P.headerBg)
    local right = "net:" .. cfg.network .. " #" .. myId
    if state.mode == "remote" then right = "REMOTE " .. right end
    if #right + 18 <= w then writeAt(w - #right, 1, right, P.headerDim, P.headerBg) end

    -- controlled gate summary
    local ctl = controlledGate()
    if ctl then
        local name = (ctl.isRemote and ">> " or "") .. ctl.name
        local badge = " " .. ctl.status .. " "
        local extra = ""
        if ctl.iris then extra = extra .. " Iris:" .. ctl.iris end
        if formatEnergy(ctl.energy) then extra = extra .. " " .. formatEnergy(ctl.energy) end
        name = clip(name, math.max(4, w - #badge - 3))
        writeAt(2, 2, name, P.text, colors.black)
        local x = 3 + #name
        writeAt(x, 2, badge, colors.black, STATUS_COLOR[ctl.status] or colors.white)
        x = x + #badge
        if x <= w then writeAt(x, 2, clip(extra, w - x + 1), P.dim, colors.black) end
    else
        writeAt(2, 2, clip("No gate selected - press G", w - 2), P.dim, colors.black)
    end
    local line3, c3 = connectionLine(ctl)
    writeAt(2, 3, clip(line3, w - 2), c3, colors.black)

    -- column header
    local showType = w >= 36
    local statusW = 8
    local statusX = w - statusW + 1
    local typeW = 9
    local nameX = 3
    local typeX = statusX - typeW - 1
    local nameW = (showType and typeX or statusX) - nameX - 1
    fillLine(4, P.barBg)
    writeAt(nameX, 4, pad("Destination", nameW), P.barFg, P.barBg)
    if showType then writeAt(typeX, 4, pad("Type", typeW), P.barFg, P.barBg) end
    writeAt(statusX, 4, padLeft("Status", statusW), P.barFg, P.barBg)

    -- list
    if #items == 0 then
        writeAt(3, L.listTop, clip("No gates found yet", w - 3), P.dim, colors.black)
    end
    for row = 1, L.listRows do
        local index = state.scroll + row
        local it = items[index]
        if not it then break end
        local y = L.listTop + row - 1
        local selected = index == sel
        local bg = selected and P.selBg or colors.black
        local fg = selected and P.selFg or P.text
        fillLine(y, bg)

        local status, statusColor, gtype
        if it.kind == "gate" then
            local online = isOnline(it.entry)
            status = online and it.entry.status or "OFFLINE"
            statusColor = STATUS_COLOR[status] or fg
            gtype = it.entry.gtype or "Gate"
            if not online then fg = selected and P.selFg or colors.gray end
        else
            status = it.address and ((#it.address + 1) .. "-chev") or ""
            statusColor = selected and P.selFg or P.dim
            gtype = "Book"
        end
        if selected and (not isColor or statusColor == colors.lightGray
            or statusColor == colors.white or statusColor == colors.gray) then
            statusColor = P.selFg
        end

        writeAt(1, y, selected and ">" or " ", fg, bg)
        local controlled = it.kind == "gate" and state.controlId == it.entry.id
        writeAt(2, y, controlled and "*" or " ", fg, bg)
        writeAt(nameX, y, pad(it.name, nameW), fg, bg)
        if showType then writeAt(typeX, y, pad(gtype, typeW), selected and P.selFg or P.dim, bg) end
        writeAt(statusX, y, padLeft(status, statusW), statusColor, bg)
    end
    if state.scroll > 0 then writeAt(w, L.listTop, "^", P.dim, colors.black) end
    if state.scroll + L.listRows < #items then writeAt(w, L.listTop + L.listRows - 1, "v", P.dim, colors.black) end

    -- detail line for the selection
    local it = items[sel]
    if it then
        local text = it.address and addrToString(it.address) or "address unknown"
        if it.kind == "gate" then
            local e = it.entry
            if isOnline(e) then
                text = text .. "  seen " .. formatAgo(os.clock() - e.lastSeen)
            else
                text = text .. "  offline"
            end
            if e.remote then text = text .. ", remote" end
        else
            text = text .. "  address book"
        end
        writeAt(2, L.detail, clip(text, w - 2), P.dim, colors.black)
    end

    -- log
    for i = 1, L.logRows do
        local entry = logLines[#logLines - L.logRows + i]
        if entry then
            writeAt(1, L.logTop + i - 1, entry.time, colors.gray, colors.black)
            writeAt(7, L.logTop + i - 1, clip(entry.text, w - 6), entry.color, colors.black)
        end
    end

    -- footer
    fillLine(L.footer, P.barBg)
    writeAt(1, L.footer, clip(footerText(w), w), colors.white, P.barBg)

    if win then win.setVisible(true) end
end

local redrawQueued = false
requestRedraw = function()
    if not redrawQueued then
        redrawQueued = true
        os.queueEvent("sgnet_redraw")
    end
end

-- read() swallows our redraw events while a modal is open, so re-arm afterwards
local function endModal()
    state.modal = false
    redrawQueued = false
    requestRedraw()
end

-- one line input at the bottom of the screen
local function prompt(label, default, mask)
    state.modal = true
    local _, h = term.getSize()
    term.setCursorPos(1, h)
    term.setBackgroundColor(color(colors.gray))
    term.clearLine()
    term.setTextColor(color(colors.yellow))
    term.write(label)
    term.setTextColor(colors.white)
    term.setCursorBlink(true)
    local input = read(mask, nil, nil, default)
    term.setCursorBlink(false)
    endModal()
    return input
end

local function confirm(question)
    local answer = prompt(question .. " (y/n) ", "")
    return answer and answer:lower():sub(1, 1) == "y"
end

local function showHelp()
    state.modal = true
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(color(colors.yellow))
    print("StargateNetwork v" .. VERSION .. " - keys")
    term.setTextColor(colors.white)
    local lines = {
        "Up/Down  pick a destination",
        "Enter    dial it (or click it twice)",
        "M        dial a typed address",
        "D        close the gate / stop dialing",
        "I        open or close the iris",
        "G        switch which gate you control",
        "R        ask all gates to report in",
        "X/Del    remove the selected entry",
        "S        setup (name, network, key)",
        "Q        quit",
    }
    for _, l in ipairs(lines) do print(l) end
    term.setTextColor(color(colors.gray))
    print("")
    write("Press any key...")
    while true do
        local e = os.pullEvent()
        if e == "key" or e == "mouse_click" then break end
    end
    endModal()
end

local function setupWizard()
    state.modal = true
    local oldNetwork = cfg.network

    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)
    term.setTextColor(color(colors.yellow))
    print("StargateNetwork setup")
    term.setTextColor(color(colors.lightGray))
    print("Press Enter to keep the value shown.")
    print("")

    local function ask(question, default, mask)
        term.setTextColor(colors.white)
        print(question)
        term.setTextColor(color(colors.lightBlue))
        write("> ")
        local answer = read(mask, nil, nil, default or "")
        return trim(answer or "")
    end

    local function askYesNo(question, default)
        local answer = ask(question .. " (y/n)", default and "y" or "n")
        return answer:lower():sub(1, 1) == "y"
    end

    if state.mode == "gate" then
        local name = ask("Name of this gate:", cfg.name or os.getComputerLabel() or ("Gate " .. myId))
        cfg.name = cleanString(name, MAX_NAME)
        if not cfg.name or cfg.name == "" then cfg.name = "Gate " .. myId end
    end

    local network = ask("Network name (gates must match):", cfg.network)
    network = network:gsub("[^%w_%-]", ""):sub(1, 16)
    cfg.network = network ~= "" and network or "default"

    cfg.key = ask("Network key for remote control (blank = off):", cfg.key, "*")

    if state.mode == "gate" then
        if cfg.key ~= "" then
            cfg.allowRemote = askYesNo("Allow others with the key to control this gate?", cfg.allowRemote)
        end
        if has("closeIris") then
            cfg.autoIris = askYesNo("Auto-iris (closes for unknown callers)?", cfg.autoIris)
        end
        if not has("getLocalAddress") then
            local current = cfg.address and table.concat(cfg.address, "-") or ""
            while true do
                local text = ask("This gate's address, e.g. 1-2-3-4-5-6 (blank = unknown):", current)
                if text == "" then
                    cfg.address = nil
                    break
                end
                local addr, err = parseAddress(text)
                if addr then
                    cfg.address = addr
                    break
                end
                term.setTextColor(color(colors.red))
                print(err)
            end
            state.address = cfg.address
        end
    end

    saveConfig()
    if state.mode == "gate" and not os.getComputerLabel() and cfg.name then
        pcall(os.setComputerLabel, cfg.name)
    end

    protocol = PROTOCOL_PREFIX .. cfg.network
    if cfg.network ~= oldNetwork then
        directory = {}
        state.controlId = nil
        saveDirectory()
        if state.started then netBroadcast({ type = "hello" }) end
    end
    if state.started then announce() end

    term.setCursorBlink(false)
    endModal()
end

local function removeSelected(items, index)
    local it = items[index]
    if not it then return end
    if it.kind == "book" then
        if confirm("Remove " .. it.name .. " from the book?") then
            table.remove(cfg.book, it.index)
            saveConfig()
            log("Removed " .. it.name, colors.lightGray)
        end
    else
        if isOnline(it.entry) then
            log("Only offline gates can be removed", colors.red)
        elseif confirm("Forget gate " .. it.name .. "?") then
            directory[it.entry.id] = nil
            if state.controlId == it.entry.id then state.controlId = nil end
            saveDirectory()
            log("Forgot " .. it.name, colors.lightGray)
        end
    end
end

local function manualDial()
    local text = prompt("Address: ", "")
    if not text or trim(text) == "" then return end
    local addr, err = parseAddress(text)
    if not addr then
        log(err, colors.red)
        return
    end
    local name = trim(prompt("Save as (blank = don't save): ", "") or "")
    if name ~= "" then
        name = cleanString(name, MAX_NAME)
        table.insert(cfg.book, { name = name, address = addr })
        saveConfig()
        state.selKey = "b:" .. #cfg.book
        log("Saved " .. name .. " to the address book", colors.lime)
    end
    dialTo(addr)
end

local function dialItem(it)
    if not it then return end
    if not it.address then
        log(it.name .. " has no known address", colors.red)
        return
    end
    dialTo(it.address)
end

local INPUT_EVENTS = { key = true, char = true, mouse_click = true, mouse_scroll = true }

local function handleInput(ev)
    local name = ev[1]
    local items = buildItems()
    local L = layout()
    local sel = selectedIndex(items)

    local function selectIndex(index)
        if #items == 0 then return end
        index = math.max(1, math.min(#items, index))
        state.selKey = items[index].key
        ensureVisible(index, L.listRows)
        requestRedraw()
    end

    if name == "key" then
        local k = ev[2]
        if k == keys.up then selectIndex(sel - 1)
        elseif k == keys.down then selectIndex(sel + 1)
        elseif k == keys.pageUp then selectIndex(sel - L.listRows)
        elseif k == keys.pageDown then selectIndex(sel + L.listRows)
        elseif k == keys.home then selectIndex(1)
        elseif k == keys["end"] then selectIndex(#items)
        elseif k == keys.enter or k == keys.numPadEnter then dialItem(items[sel])
        elseif k == keys.delete then removeSelected(items, sel)
        end
    elseif name == "char" then
        -- letters are handled on "char" so the key never leaks into a prompt
        local c = ev[2]:lower()
        if c == "q" then
            return "quit"
        elseif c == "m" then manualDial()
        elseif c == "d" then disconnectControlled()
        elseif c == "i" then toggleIrisControlled()
        elseif c == "g" then cycleControl()
        elseif c == "r" then
            netBroadcast({ type = "hello" })
            announce()
            log("Asked all gates to report in", colors.lightGray)
        elseif c == "x" then removeSelected(items, sel)
        elseif c == "s" then setupWizard()
        elseif c == "h" or c == "?" then showHelp()
        end
        requestRedraw()
    elseif name == "mouse_click" then
        local y = ev[4]
        if y >= L.listTop and y < L.listTop + L.listRows then
            local index = state.scroll + (y - L.listTop) + 1
            if items[index] then
                if index == sel then
                    dialItem(items[index])
                else
                    selectIndex(index)
                end
            end
        end
    elseif name == "mouse_scroll" then
        selectIndex(sel + ev[2])
    end
end

local function uiLoop()
    draw()
    while true do
        local ev = pack(os.pullEvent())
        local name = ev[1]
        if name == "sgnet_redraw" then
            redrawQueued = false
            if not state.modal then draw() end
        elseif name == "term_resize" then
            local w, h = native.getSize()
            win.reposition(1, 1, w, h)
            draw()
        elseif INPUT_EVENTS[name] then
            if handleInput(ev) == "quit" then return end
        end
    end
end

-- ==========================================================================
--  BACKGROUND LOOPS
-- ==========================================================================

local function netLoop()
    if not modemName then
        while true do os.pullEvent("sgnet_never") end
    end
    while true do
        local sender, msg = rednet.receive(protocol)
        if sender then onMessage(sender, msg) end
    end
end

local function gateEventLoop()
    while true do
        local ev = pack(os.pullEvent())
        local name = ev[1]
        if type(name) == "string" and name:sub(1, 9) == "stargate_" and ev[2] == ifaceName then
            handleGateEvent(ev)
        end
    end
end

local function statusLoop()
    while true do
        if state.mode == "gate" and refreshLocal() then
            announce()
            requestRedraw()
        end
        sleep(1)
    end
end

local function heartbeatLoop()
    local elapsed = 0
    while true do
        sleep(5)
        elapsed = elapsed + 5
        if elapsed % HEARTBEAT_EVERY == 0 then
            if state.mode == "gate" then
                refreshLocal()
                announce()
            end
        end
        for _, e in pairs(directory) do
            if e.lastSeen and not isOnline(e) then
                e.lastSeen = nil
                log(e.name .. " went offline", colors.gray)
            end
        end
        requestRedraw()
    end
end

-- ==========================================================================
--  MAIN
-- ==========================================================================

local function main()
    loadConfig()
    protocol = PROTOCOL_PREFIX .. cfg.network

    local w, h = native.getSize()
    win = window.create(native, 1, 1, w, h, true)
    term.redirect(win)

    if modemName then rednet.open(modemName) end

    if iface then
        state.gtype = shortType(call("getStargateType"))
        state.address = readLocalAddress()
    end

    if firstRun or args[1] == "setup" or (state.mode == "gate" and not cfg.name) then
        setupWizard()
    end

    loadDirectory()
    if iface then
        refreshLocal()
        state.outgoing = call("isStargateDialingOut")
        if state.status == "INCOMING" then state.inWormhole = call("isStargateConnected") == true end
    end

    log("StargateNetwork v" .. VERSION .. " started", colors.lightBlue)
    if iface then
        log("Gate: " .. (state.gtype or "?") .. " via " .. ifaceType:gsub("_", " "), colors.lightGray)
        if not state.address then
            log("Address unknown - others can't dial us", colors.yellow)
        end
    else
        log("No interface found: remote control mode", colors.yellow)
    end
    if not modemName then
        log("No modem found: network disabled", colors.red)
    end

    netBroadcast({ type = "hello" })
    announce()
    state.started = true

    parallel.waitForAny(uiLoop, netLoop, gateEventLoop, statusLoop, heartbeatLoop, dialWorker)
end

local ok, err = pcall(main)

if state.mode == "gate" and modemName and protocol then
    pcall(netBroadcast, { type = "bye" })
end
term.redirect(native)
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.setCursorBlink(false)
term.clear()
term.setCursorPos(1, 1)
if not ok and err ~= "Terminated" then
    printError(err)
else
    print("StargateNetwork stopped.")
end
