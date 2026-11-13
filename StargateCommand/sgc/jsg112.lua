--
-- sgc.jsg112 - Just Stargate Mod (JSG) for Minecraft 1.12.2, through its
-- OpenComputers "stargate" component (the gate's base block)
--
-- Read from JSG 1.12.2 4.11.2.8:
--   methods  engageSymbol(name), engageGate(), disengageGate(), abortDialing(),
--            getGateStatus() -> "idle" | "dialing" | "dialing_computer" | "open", initiating
--                              | "unstable" | "failing" | "incoming" | "not_merged",
--            getGateType(), getIrisState(), getIrisType(), toggleIris(), getEnergyStored(),
--            sendIrisCode(code), sendMessageToIncoming(text),
--            stargateAddress and dialedAddress (fields; dialedAddress is a string such as
--            "[Eridanus, Crater]", and a symbol is listed once its chevron has locked)
--   signals  (component address, caller, ...) stargate_spin_start, stargate_spin_chevron_engaged
--            (count, final, symbol), stargate_dhd_chevron_engaged (count, final, symbol),
--            stargate_incoming_wormhole (size), stargate_open (initiating),
--            stargate_wormhole_stabilized (initiating), stargate_close (reason),
--            stargate_wormhole_closed_fully, stargate_failed (reason),
--            stargate_traveler (inbound, player, class), stargate_event_iris_hit, received_code (code)
--
-- Iris codes use JSG's own GDO: "IDC:<code>" goes out with sendIrisCode, a received_code
-- signal comes in as "IDC:<code>", and the answers go to the traveller with sendMessageToIncoming.
--

local A = require("sgc.address")

local M = {}

local function now() return os.clock() end

local IRIS = { OPENED = 0, OPENING = 40, CLOSING = 60, CLOSED = 100 }

local TYPES = {
    { "milky",    "milky_way", "Milky Way", 39, nil, "MILKYWAY" },
    { "pegasus",  "pegasus",   "Pegasus",   36, nil, "PEGASUS" },
    { "universe", "universe",  "Universe",  36, nil, "UNIVERSE" },
    { "orlin",    "milky_way", "Orlin",     39, "orlin", "MILKYWAY" },
}

local ORIGIN = { milky_way = "Point of Origin", pegasus = "Subido", universe = "G17" }

-- "stargate_failure_busy" -> "Failure busy"
function M.reason(r)
    r = tostring(r or ""):lower():gsub("^stargate_", ""):gsub("_", " ")
    return (r:gsub("^%l", string.upper))
end

local function failed(result)
    if type(result) ~= "string" then return false end
    return result:find("failure", 1, true) ~= nil or result:find("failed", 1, true) ~= nil
        or result:find("not_", 1, true) ~= nil or result:find("missing", 1, true) ~= nil
        or result:find("error", 1, true) ~= nil or result:find("invalid", 1, true) ~= nil
end

-- calls a JSG method; returns true, or false + a reason + JSG's code
-- (a refusal comes back as nil, "stargate_failure_busy", "Stargate is busy, ...")
local function command(g, method, ...)
    local pc, result, code, text = g:try(method, ...)
    if not pc then return false, (tostring(result):gsub("^.-:%d+: ", "")) end
    if result == nil and type(code) == "string" then
        return false, type(text) == "string" and text or M.reason(code), code
    end
    if failed(result) then return false, type(code) == "string" and code or M.reason(result), result end
    return true
end

-- JSG refuses a command while the ring turns or a chevron is still locking:
-- try again until the gate takes it
local function untilAccepted(g, opts, timeout, method, ...)
    local G = require("sgc.gate")
    local args = table.pack(...)
    local lastWhy
    local accepted = G.waitUntil(opts, function()
        local ok, why, code = command(g, method, table.unpack(args, 1, args.n))
        if ok then return true end
        if code ~= "stargate_failure_busy" then G.fail(why) end
        lastWhy = why
        return false
    end, timeout)
    if not accepted then G.fail(lastWhy or "The gate stayed busy") end
end

-- the symbols dialed so far, from dialedAddress ("[Eridanus, Crater]" or a table)
function M.dialedList(value)
    local list = {}
    if type(value) == "table" then
        for i, s in ipairs(value) do list[i] = s end
    elseif type(value) == "string" then
        local inner = value:match("^%s*%[(.*)%]%s*$") or value
        for name in inner:gmatch("[^,]+") do
            name = name:match("^%s*(.-)%s*$")
            if name ~= "" then list[#list + 1] = name end
        end
    end
    return list
end

local function status(g)
    local st, initiating = g:call("getGateStatus")
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
    local symbolType = "MILKYWAY"
    for _, ty in ipairs(TYPES) do
        if t:find(ty[1], 1, true) then
            g.typeId, g.typeName, g.symbolCount, g.variant, symbolType = ty[2], ty[3], ty[4], ty[5], ty[6]
            break
        end
    end
    g.originSymbol = ORIGIN[g.typeId] or "Point of Origin"
    g.energyUnit = "RF"
    local map = g:call("stargateAddress")
    if type(map) == "table" then
        local own = map[symbolType]
        if not own then for _, v in pairs(map) do own = own or v end end
        if type(own) == "table" then
            -- the first six symbols; the rest are for 8 and 9 chevron dialing
            local six = {}
            for i = 1, math.min(6, #own) do six[i] = own[i] end
            g.localAddress = A.fromValue(six)
        end
    end
    local irisType = g:call("getIrisType")
    g.hasIris = type(irisType) == "string" and irisType ~= "NULL"
end

function M.poll(g)
    local st, initiating = status(g)
    if not st or st == "not_merged" then
        g.state = "OFFLINE"
        return g.state
    end
    local wasConnected = g.connected
    if st == "open" or st == "unstable" then
        g.connected = true
        if initiating ~= nil then g.outgoing = initiating == true end
        g.state = g.outgoing and "OPEN" or "INCOMING"
        if not wasConnected and not g.openedAt then g.openedAt = now() - 10 end
    else
        g.connected = false
        if st == "idle" then
            g.state = "IDLE"
            g.remote, g.engaged, g.openedAt, g.incomingChevrons = nil, {}, nil, false
        elseif st == "incoming" then
            g.state, g.outgoing, g.incomingChevrons = "INCOMING", false, true
        elseif st:find("dialing", 1, true) then
            g.state, g.outgoing = "DIALING", true
        else
            g.state = "CLOSING" -- failing
        end
    end
    if g.dialing and not g.connected and g.state ~= "INCOMING" then g.state = "DIALING" end
    if st ~= "idle" then
        local list = M.dialedList(g:call("dialedAddress"))
        g.engaged = list
        if not g.connected then g.chevrons = #list end
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
    return nil
end

-- e[o] is the caller, the values follow
function M.event(g, name, e, o)
    local p = o + 1
    if name == "stargate_spin_start" then
        return { type = "rotation", started = true }
    elseif name == "stargate_spin_chevron_engaged" or name == "stargate_dhd_chevron_engaged" then
        local n = tonumber(e[p])
        g.chevrons = n or g.chevrons
        if n and e[p + 2] then g.engaged[n] = e[p + 2] end
        return { type = "chevron", n = n, symbol = e[p + 2], incoming = false }
    elseif name == "stargate_incoming_wormhole" then
        g.outgoing, g.incomingChevrons = false, true
        g.chevrons = tonumber(e[p]) or g.chevrons
        return { type = "dialin" }
    elseif name == "stargate_open" then
        local initiating = e[p] == true
        g.outgoing = initiating
        g.connected, g.openedAt = true, now()
        if initiating and g.engaged and #g.engaged > 0 then g.remote = A.strip(g.engaged) end
        return { type = initiating and "outgoing" or "incoming", address = initiating and g.remote or nil }
    elseif name == "stargate_close" then
        if g.connected then g.closingAt = now() end
        g.connected, g.openedAt = false, nil
        return { type = "closed", reason = e[p] and M.reason(e[p]) or nil }
    elseif name == "stargate_failed" then
        g.lastFailure = M.reason(e[p])
        return { type = "reset", error = true, reason = g.lastFailure }
    elseif name == "stargate_traveler" then
        -- JSG names the traveller by its Java class: EntityPlayerMP, EntityPig...
        local who = e[p + 1] == true and "A player" or tostring(e[p + 2] or "Something"):gsub("^Entity", "")
        return { type = "traveler", direction = e[p] == true and "in" or "out", name = who }
    elseif name == "stargate_event_iris_hit" then
        return { type = "thud" }
    elseif name == "received_code" then
        return { type = "message", text = "IDC:" .. tostring(e[p]) }
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

    -- one symbol at a time: the ring turns to it and the chevron locks
    for i, symbol in ipairs(list) do
        G.pause(opts)
        if opts.onStep then opts.onStep(i, symbol, #list) end
        untilAccepted(g, opts, opts.stepTimeout or 60, "engageSymbol", symbol)
        if not G.waitUntil(opts, function()
            if g.lastFailure then G.fail(g.lastFailure) end
            return #M.dialedList(g:call("dialedAddress")) >= i
        end, opts.stepTimeout or 60) then
            G.fail("Chevron " .. i .. " did not lock")
        end
        g.chevrons = i
    end

    untilAccepted(g, opts, 10, "engageGate")
    if not G.waitUntil(opts, function()
        if g.lastFailure then G.fail(g.lastFailure) end
        local st = status(g)
        if st == "idle" then G.fail("No connection was established") end
        return st == "open" or st == "unstable"
    end, opts.connectTimeout or 10) then
        G.fail("No connection was established")
    end
    g.outgoing = true
end

function M.close(g)
    local st = status(g)
    if g.connected or st == "open" or st == "unstable" then return command(g, "disengageGate") end
    return command(g, "abortDialing")
end

function M.abort(g)
    command(g, "abortDialing")
    if g.connected and g.outgoing then command(g, "disengageGate") end
end

-- JSG only toggles the iris
local function irisTo(g, closed)
    local st = tostring(g:call("getIrisState") or "")
    if closed and (st == "CLOSED" or st == "CLOSING") then return true end
    if not closed and (st == "OPENED" or st == "OPENING") then return true end
    return command(g, "toggleIris")
end

function M.openIris(g) return irisTo(g, false) end
function M.closeIris(g) return irisTo(g, true) end

-- iris codes go through JSG's GDO; other text goes to the traveller who sent a code
function M.sendMessage(g, text)
    local code = tostring(text):match("^%s*IDC:%s*([%w%-]+)%s*$")
    if code and code:upper() ~= "ACCEPTED" and code:upper() ~= "REJECTED" then
        return command(g, "sendIrisCode", code)
    end
    local reply = tostring(text):gsub("^%s*IDC:%s*ACCEPTED", "Iris code accepted:"):gsub("^%s*IDC:%s*REJECTED", "Iris code rejected")
    return command(g, "sendMessageToIncoming", reply)
end

return M
