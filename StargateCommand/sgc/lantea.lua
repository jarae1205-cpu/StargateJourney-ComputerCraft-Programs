--
-- sgc.lantea - Lantea: Stargates (by aqueoxx), 0.7.7.0 and later
--
-- A Milky Way or Pegasus gate whose controller has a Stargate Power Coupler
-- Kit is a "stargate" peripheral. Computers can dial Milky Way gates only.
-- Symbols are numbered like Stargate Journey: 1-38, the point of origin is 0.
--
-- Used by sgc.gate; the functions take the gate object.
--

local A = require("sgc.address")

local M = {}

local function now() return os.clock() end

local IRIS = { open = 0, opening = 40, closing = 60, closed = 100 }

-- stargate_dial_failed reasons
M.FAILURES = {
    source_busy = "The gate is busy", structure_incomplete = "The gate isn't complete",
    unknown_address = "No gate at that address", other_galaxy = "That gate is in another galaxy (needs a Range Crystal)",
    self_dial = "A gate can't dial itself", banned = "This gate may not dial that address",
    destination_busy = "The gate at that address is busy", destination_unavailable = "The gate at that address is unavailable",
    destination_lost = "Lost the gate at that address", destination_obstructed = "The gate at that address is obstructed",
    too_many_connections = "Too many connections", insufficient_power = "Not enough power",
    needs_zero_point_module = "That address needs a ZPM", overvoltage = "Overvoltage",
    incoming_wormhole = "Interrupted by an incoming wormhole", aborted = "Dialing aborted",
}

function M.reason(r)
    r = tostring(r or "")
    if M.FAILURES[r] then return M.FAILURES[r] end
    r = r:gsub("_", " ")
    return (r:gsub("^%l", string.upper))
end

-- error text from a refused call ("...: The ring is still turning.")
local function errorText(err)
    return (tostring(err):gsub("^.-:%d+: ", ""))
end

function M.detect(g)
    -- Milky Way gates have 39 symbols, Pegasus gates 36 (if the gate doesn't answer, assume Milky Way)
    local answers = pcall(g.p.getSymbolName, 0)
    local mw = pcall(g.p.getSymbolName, 38) or not answers
    if mw then
        g.typeId, g.typeName, g.symbolCount = "milky_way", "Milky Way", 39
    else
        g.typeId, g.typeName, g.symbolCount = "pegasus", "Pegasus", 36
    end
    g.variant = nil
    g.localAddress = A.fromValue(g:call("getLocalAddress"))
    local iris = g:call("getIrisState")
    g.hasIris = type(iris) == "string" and iris ~= "none"
    g.originSymbol = 0
    g.energyUnit = "EU"
    g.canDial = mw
end

function M.poll(g)
    local st = g:call("getState")
    if type(st) ~= "string" then
        g.state = "OFFLINE"
        return g.state
    end
    local wasConnected = g.connected
    g.chevrons = g:call("getChevronsLocked") or 0
    g.connected = st == "open"
    g.fault = st == "fault"
    if st == "idle" then
        g.state = "IDLE"
        g.remote, g.engaged, g.openedAt, g.incomingChevrons = nil, {}, nil, false
    elseif st == "dialing" or st == "connecting" then
        g.state, g.outgoing = "DIALING", true
    elseif st == "incoming" then
        g.state, g.outgoing, g.incomingChevrons = "INCOMING", false, true
    elseif st == "open" then
        g.state = g.outgoing and "OPEN" or "INCOMING"
        if not wasConnected and not g.openedAt then g.openedAt = now() - 10 end
    elseif st == "closing" or st == "resetting" then
        g.state = "CLOSING"
    else
        g.state = "OFFLINE"
    end
    if g.dialing and g.state ~= "INCOMING" and not g.connected then g.state = "DIALING" end
    if st ~= "idle" then
        local locked = g:call("getLockedSymbols")
        if type(locked) == "table" then
            local list = {}
            for i, s in ipairs(locked) do list[i] = s end
            g.engaged = list
        end
    end
    if g.hasIris then
        local iris = g:call("getIrisState")
        g.iris = IRIS[iris] or (iris ~= "none" and 50 or nil)
    else
        g.iris = nil
    end
    g.energy = g:call("getEnergy")
    return g.state
end

function M.rotation(g)
    local s = g:call("getCurrentSymbol")
    if type(s) ~= "number" then return nil end
    -- the symbol at the top of the ring
    return -(s * 360 / g.symbolCount)
end

function M.event(g, name, e, o)
    if name == "stargate_ring_stopped" then
        return { type = "rotation", started = false }
    elseif name == "stargate_chevron_locked" then
        return { type = "chevron", n = e[o], symbol = e[o + 1], incoming = g.state == "INCOMING" }
    elseif name == "stargate_incoming" then
        g.outgoing, g.incomingChevrons = false, true
        return { type = "dialin" }
    elseif name == "stargate_wormhole_open" then
        g.outgoing = e[o] == "outgoing"
        g.connected, g.openedAt = true, now()
        if not g.outgoing then g.remote = nil end
        return { type = g.outgoing and "outgoing" or "incoming", address = g.remote }
    elseif name == "stargate_wormhole_closed" then
        if g.connected then g.closingAt = now() end
        g.connected, g.openedAt = false, nil
        return { type = "closed" }
    elseif name == "stargate_dial_failed" then
        g.lastFailure = M.reason(e[o])
        return { type = "reset", error = e[o] ~= "aborted", reason = g.lastFailure }
    elseif name == "stargate_iris" then
        return { type = "iris", state = e[o] }
    elseif name == "stargate_iris_struck" then
        return { type = "thud" }
    end
    return nil
end

function M.dial(g, address, opts)
    local G = require("sgc.gate")
    if not g.canDial then G.fail("Lantea Pegasus gates can't be dialed by a computer") end
    if g:call("getState") ~= "idle" then G.fail("The gate is busy") end
    local list = A.strip(address)
    list[#list + 1] = 0
    g.lastFailure, g.engaged, g.outgoing, g.remote = nil, {}, true, A.strip(address)
    local stepTimeout = opts.stepTimeout or 60

    local function failed()
        if g.lastFailure then G.fail(g.lastFailure) end
    end

    for i, s in ipairs(list) do
        G.pause(opts)
        if opts.onStep then opts.onStep(i, s, #list) end
        -- wait until the ring is still and a chevron can lock
        if not G.waitUntil(opts, function()
            failed()
            return not g:call("isRingTurning") and (g:call("getNextChevron") or 0) > 0
        end, stepTimeout) then
            G.fail("The gate is not ready for chevron " .. i)
        end
        -- turns the ring to the symbol and locks it; the point of origin reaches out.
        -- Lantea counts a chevron as locked about a second before it has finished
        -- locking, and refuses the next symbol until then: wait and try again.
        local ok, err
        local deadline = os.clock() + stepTimeout
        while true do
            ok, err = g:try("encodeSymbol", s)
            if ok or not tostring(err):find("still locking", 1, true) or os.clock() > deadline then break end
            G.pause(opts, 0.25)
        end
        if not ok then G.fail(errorText(err)) end
        if i < #list then
            if not G.waitUntil(opts, function()
                failed()
                return (g:call("getChevronsLocked") or 0) >= i
            end, stepTimeout) then
                G.fail("Chevron " .. i .. " did not lock")
            end
            G.pause(opts, opts.fast and 0 or (opts.symbolDelay or 0.5))
        end
    end

    if not G.waitUntil(opts, function()
        failed()
        local st = g:call("getState")
        if st == "idle" or st == "fault" then G.fail("No connection was established") end
        return st == "open"
    end, stepTimeout + (opts.connectTimeout or 10)) then
        G.fail("No connection was established")
    end
    g.outgoing = true
end

function M.close(g)
    local st = g:call("getState")
    -- a failed dial resets the gate by itself
    if st == "idle" or st == "resetting" or st == "closing" then return true end
    if st == "open" or st == "connecting" then
        local ok, err = g:try("close")
        if ok then return true end
        return false, errorText(err)
    end
    local ok, err = g:try("abort")
    return ok, not ok and errorText(err) or nil
end

function M.abort(g)
    local st = g:call("getState")
    if st == "idle" or st == "resetting" then return end
    g:try("abort")
    if g:call("getState") == "open" and g.outgoing then g:try("close") end
end

return M
