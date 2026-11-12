--
-- sgc.jsg - Just Stargate Mod (JSG) for Minecraft 1.20.1, through its
-- CC: Tweaked "stargate" peripheral (the gate's base block)
--
-- Addresses are symbol names, e.g. { "Crater", "Virgo", "Bootes", "Centaurus",
-- "Libra", "Serpens Caput" }; the point of origin ("Point of Origin" on Milky
-- Way gates, "Subido" on Pegasus gates, "G17" on Universe gates) is added
-- when dialing. Most JSG methods answer (ok, code, message).
--
-- Used by sgc.gate; the functions take the gate object.
--

local A = require("sgc.address")

local M = {}

local function now() return os.clock() end

local IRIS = { OPENED = 0, OPENING = 40, CLOSING = 60, CLOSED = 100 }

local TYPES = {
    { "milky",    "milky_way", "Milky Way", 39, nil },
    { "pegasus",  "pegasus",   "Pegasus",   36, nil },
    { "universe", "universe",  "Universe",  36, nil },
    { "tollan",   "tollan",    "Tollan",    39, nil },
    { "movie",    "milky_way", "Movie",     39, "movie" },
    { "orlin",    "milky_way", "Orlin",     39, "orlin" },
}

local ORIGIN = { milky_way = "Point of Origin", pegasus = "Subido", universe = "G17", tollan = "Point of Origin" }

-- "NOT_ENOUGH_POWER" / "stargate_failure_busy" -> "Not enough power" / "Stargate failure busy"
function M.reason(r)
    r = tostring(r or ""):lower():gsub("^stargate_", ""):gsub("_", " ")
    return (r:gsub("^%l", string.upper))
end

local function errorText(err)
    return (tostring(err):gsub("^.-:%d+: ", ""))
end

-- calls a JSG method that answers (ok, code, message); returns true or false + text
local function command(g, method, ...)
    local pc, ok, code, msg = g:try(method, ...)
    if not pc then return false, errorText(ok) end
    if ok == false then return false, msg or M.reason(code) end
    return true
end

local function status(g)
    local ok, st, initiating = g:call("getGateStatus")
    if ok == false then return "not_merged" end
    return type(st) == "string" and st:lower() or nil, initiating
end

local function firstNumber(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "number" then return v end
    end
end

function M.detect(g)
    local t = tostring(g:call("getGateType") or ""):lower()
    g.typeId, g.typeName, g.symbolCount, g.variant = "milky_way", "Milky Way", 39, nil
    for _, ty in ipairs(TYPES) do
        if t:find(ty[1], 1, true) then
            g.typeId, g.typeName, g.symbolCount, g.variant = ty[2], ty[3], ty[4], ty[5]
            break
        end
    end
    g.originSymbol = ORIGIN[g.typeId] or "Point of Origin"
    g.energyUnit = "FE"
    -- the gate's own address for its symbol type
    local map = g:call("getStargateAddress")
    local symbolType = g:call("getSymbolType")
    if type(map) == "table" then
        local own = map[symbolType]
        if not own then for _, v in pairs(map) do own = own or v end end
        g.localAddress = A.fromValue(own)
    end
    local irisType = g:call("getIrisType")
    g.hasIris = type(irisType) == "string" and irisType ~= "NULL"
    g.irisType = irisType
end

function M.poll(g)
    local st, initiating = status(g)
    if not st or st == "not_merged" then
        g.state = "OFFLINE"
        return g.state
    end
    local wasConnected = g.connected
    g.jsgStatus = st
    if st == "open" or st:find("unstable_opening", 1, true) then
        g.connected = true
        if st == "open" and initiating ~= nil then g.outgoing = initiating == true end
        g.state = g.outgoing and "OPEN" or "INCOMING"
        if not wasConnected and not g.openedAt then g.openedAt = now() - (st == "open" and 10 or 0) end
    else
        g.connected = false
        if st == "idle" then
            g.state = "IDLE"
            g.remote, g.engaged, g.openedAt, g.incomingChevrons = nil, {}, nil, false
        elseif st == "incoming" then
            g.state, g.outgoing, g.incomingChevrons = "INCOMING", false, true
        elseif st:find("dialing", 1, true) then
            g.state = g.incomingChevrons and not g.dialing and "INCOMING" or "DIALING"
            if g.state == "DIALING" then g.outgoing = true end
        else
            -- unstable_closing, failing, resetting
            g.state = "CLOSING"
        end
    end
    if g.dialing and not g.connected and g.state ~= "INCOMING" then g.state = "DIALING" end
    if st ~= "idle" then
        local dialed = g:call("getDialedAddress")
        if type(dialed) == "table" then
            local list = {}
            for i, s in ipairs(dialed) do list[i] = s end
            g.engaged = list
            if not g.connected then g.chevrons = #list end
        end
    else
        g.chevrons = 0
    end
    if g.hasIris then
        g.iris = IRIS[tostring(g:call("getIrisState") or "")] or 50
    else
        g.iris = nil
    end
    g.energy = firstNumber(g:call("getEnergyStored"))
    return g.state
end

function M.rotation(g)
    if not g:has("getRingAngle") then return nil end
    return firstNumber(g:call("getRingAngle"))
end

function M.event(g, name, e, o)
    if name == "stargate_spin_start" then
        return { type = "rotation", started = true }
    elseif name == "stargate_spin_stop" then
        return { type = "rotation", started = false }
    elseif name == "stargate_chevron_engaged" then
        -- (source, symbol name, chevron, count)
        local n = tonumber(e[o + 3]) or tonumber(e[o + 2])
        return { type = "chevron", n = n, symbol = e[o + 1], incoming = g.incomingChevrons and not g.dialing }
    elseif name == "stargate_wormhole_incoming" then
        g.outgoing, g.incomingChevrons = false, true
        return { type = "dialin" }
    elseif name == "stargate_wormhole_open_unstable" then
        local addr = A.fromValue(e[o])
        if g.dialing or g.state == "DIALING" then g.outgoing = true
        elseif g.state == "INCOMING" or g.incomingChevrons then g.outgoing = false end
        g.connected, g.openedAt = true, now()
        if addr then g.remote = addr end
        if not g.outgoing and g.remote then g.lastIncoming = g.remote end
        return { type = g.outgoing and "outgoing" or "incoming", address = g.remote }
    elseif name == "stargate_wormhole_close_unstable" then
        if g.connected then g.closingAt = now() end
        g.connected, g.openedAt = false, nil
        return { type = "closed", reason = e[o + 1] and M.reason(e[o + 1]) or nil }
    elseif name == "stargate_attempt_open_failed" then
        g.lastFailure = M.reason(e[o])
        return { type = "reset", error = true, reason = g.lastFailure }
    elseif name == "stargate_event_horizon_traveler" then
        return { type = "traveler", direction = g.outgoing and "out" or "in", name = e[o + 1] }
    elseif name == "stargate_iris_state_changed" then
        return { type = "iris", state = e[o] }
    elseif name == "stargate_iris_hit" then
        return { type = "thud" }
    end
    return nil
end

function M.dial(g, address, opts)
    local G = require("sgc.gate")
    if status(g) ~= "idle" then G.fail("The gate is busy") end
    local names = A.strip(address)
    local list = {}
    for i, s in ipairs(names) do list[i] = s end
    list[#list + 1] = g.originSymbol
    g.lastFailure, g.engaged, g.outgoing, g.remote, g.incomingChevrons = nil, {}, true, names, false

    local ok, why = command(g, "dialAddress", list)
    if not ok then G.fail(why) end

    -- the gate dials the symbols itself
    local seen = 0
    local opened = false
    local finished = G.waitUntil(opts, function()
        if g.lastFailure then G.fail(g.lastFailure) end
        local st = status(g)
        local dialed = g:call("getDialedAddress")
        local count = type(dialed) == "table" and #dialed or 0
        while seen < count and seen < #list do
            seen = seen + 1
            g.chevrons = seen
            if opts.onStep then opts.onStep(seen, list[seen], #list) end
        end
        if st == "open" or (st and st:find("unstable_opening", 1, true)) then
            opened = true
            return true
        end
        if st == "idle" and count >= #list then return true end
        if st == "idle" and seen > 0 and count == 0 then G.fail("The gate stopped dialing") end
        return false
    end, (opts.stepTimeout or 60) + 8 * #list)
    if not finished then G.fail("The gate did not finish dialing") end

    -- a fully dialed gate is opened with engageGate
    if not opened then
        ok, why = command(g, "engageGate")
        if not ok then G.fail(why) end
    end
    if not G.waitUntil(opts, function()
        if g.lastFailure then G.fail(g.lastFailure) end
        local st = status(g)
        if st == "idle" then G.fail("No connection was established") end
        return st == "open" or (st and st:find("unstable_opening", 1, true)) ~= nil
    end, opts.connectTimeout or 10) then
        G.fail("No connection was established")
    end
    g.outgoing = true
end

function M.close(g)
    local st = status(g)
    if g.connected or st == "open" then return command(g, "disengageGate") end
    return command(g, "abortDialing")
end

function M.abort(g)
    command(g, "abortDialing")
    if g.connected and g.outgoing then command(g, "disengageGate") end
end

-- JSG only toggles the iris (its iris mode must be set to OC / computer)
local function irisTo(g, closed)
    local st = tostring(g:call("getIrisState") or "")
    if closed and (st == "CLOSED" or st == "CLOSING") then return true end
    if not closed and (st == "OPENED" or st == "OPENING") then return true end
    return command(g, "toggleIris")
end

function M.openIris(g) return irisTo(g, false) end
function M.closeIris(g) return irisTo(g, true) end

return M
