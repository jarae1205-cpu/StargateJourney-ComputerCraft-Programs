--
-- sgc.lanteacraft - LanteaCraft (by Michiyo and AfterLifeLochie), 0.2.5 and later, Minecraft 1.21.1
--
-- The gate's base block is a "stargate" peripheral (CC: Tweaked) or component (OpenComputers).
-- An address is 7 to 9 glyphs from A-Z, 0-9, "-" and "+"; the last one names the dimension
-- (A the overworld, N the Nether, E the End), so "-" is part of the address, not a separator.
-- One dial() call dials the whole address and the gate locks the chevrons itself,
-- about 3 seconds each. An incoming wormhole can only be closed by the gate that dialed it.
--
-- Iris codes use LanteaCraft's GDO. The gate keeps one code (setGdoCode, or its screen); a
-- traveller's GDO sends a code and the gate opens or closes its iris by itself if it matches.
-- Either way the computer hears about it (stargate_idc_received). A computer can't send a code.
--
-- Events: stargate_event (name, details) for dialing, opened, closed, entity_transit and
-- gdo_signal; stargate_idc_received (name, address, code, accepted, action, irisClosed, redstoneLocked)
--
-- Used by sgc.gate; the functions take the gate object.
--

local M = {}

local function now() return os.clock() end

local IRIS = { open = 0, opening = 40, closing = 60, closed = 100 }

-- dial() and disconnect() result codes; the mod's own message is used when there is one
M.FAILURES = {
    invalid_address = "Malformed address", unknown_address = "No stargate at that address",
    local_address = "A gate can't dial itself", target_unavailable = "The gate at that address is unavailable",
    destination_disabled = "The gate at that address can't be dialed", incoming_active = "An incoming wormhole is open",
    insufficient_power = "Not enough power", eighth_chevron_locked = "That address needs an Eighth Chevron Crystal",
    not_connected = "No outgoing wormhole to close",
}

function M.reason(code, message)
    if type(message) == "string" and message ~= "" then return (message:gsub("%.$", "")) end
    code = tostring(code or "")
    if M.FAILURES[code] then return M.FAILURES[code] end
    code = code:gsub("_", " ")
    return (code:gsub("^%l", string.upper))
end

-- error text from a refused call ("...: Stargate is not assembled")
local function errorText(err)
    return (tostring(err):gsub("^.-:%d+: ", ""))
end

-- a LanteaCraft address as the gate gives it: every glyph kept, "-" and "+" included
function M.address(v)
    if type(v) ~= "string" then return nil end
    local s = v:upper():gsub("%s", "")
    return s ~= "" and s or nil
end

local function status(g)
    local st = g:call("getStatus")
    return type(st) == "table" and st or nil
end

function M.detect(g)
    -- "-" is a glyph here, so addresses are shown and read without SGCraft's dashes
    require("sgc.address").plainLetters = true
    -- drawn like an SGCraft gate: a ring of letter glyphs with no point of origin
    g.typeId, g.typeName, g.symbolCount = "sgcraft", "LanteaCraft", 38
    g.variant = nil
    g.originSymbol = nil
    g.energyUnit = "FE"
    local st = status(g)
    g.localAddress = M.address(g:call("getAddress")) or (st and M.address(st.address))
    g.hasIris = g:call("hasIris") == true
end

function M.poll(g)
    local st = status(g)
    if not st then
        g.state = "OFFLINE"
        return g.state
    end
    local wasConnected = g.connected
    local dialing = st.dialing == true
    local dir = st.direction
    if dir == "incoming" then g.outgoing = false elseif dir == "outgoing" then g.outgoing = true end
    g.connected = st.connected == true and not dialing
    local target = M.address(st.dialingAddress) or M.address(st.remoteAddress)
    if target then g.remote = target end

    if dialing then
        local incoming = dir == "incoming" or (not g.dialing and g.incomingChevrons)
        g.state = incoming and "INCOMING" or "DIALING"
        -- the gate locks one chevron per glyph as its dialing runs
        local n = g.remote and #g.remote or 7
        local p = tonumber(st.dialProgress) or 0
        g.chevrons = math.max(0, math.min(n, math.floor(p * n + 0.001)))
    elseif g.connected then
        g.state = g.outgoing and "OPEN" or "INCOMING"
        g.chevrons = g.remote and #g.remote or 7
        if not wasConnected and not g.openedAt then g.openedAt = now() - 10 end
    elseif g.dialing then
        g.state = "DIALING"
    else
        g.state = "IDLE"
        g.remote, g.engaged, g.openedAt, g.incomingChevrons, g.chevrons = nil, {}, nil, false, 0
    end
    if g.state ~= "IDLE" and g.remote then
        local list = {}
        for i = 1, math.min(g.chevrons, #g.remote) do list[i] = g.remote:sub(i, i) end
        g.engaged = list
    end

    g.hasIris = st.irisState ~= nil and st.irisState ~= "none"
    g.iris = g.hasIris and (IRIS[st.irisState] or 50) or nil
    g.irisLocked = st.redstoneLocked == true
    g.gdoCode = st.gdoCode
    g.energy = nil
    return g.state
end

function M.rotation(g) return nil end

function M.event(g, name, e, o)
    if name == "stargate_idc_received" then
        -- this gate's address, the code, whether the gate took it, what the GDO asked for
        local code = tostring(e[o + 1] or "")
        if code == "" then return nil end
        return { type = "message", text = "IDC:" .. code, gateAccepted = e[o + 2] == true,
                 action = e[o + 3], irisClosed = e[o + 4] == true, irisLocked = e[o + 5] == true }
    end
    if name ~= "stargate_event" then return nil end
    local d = e[o]
    if type(d) ~= "table" then return nil end
    local ty, dir = d.type, d.direction
    local remote = M.address(d.remoteAddress)
    if ty == "dialing" then
        g.outgoing = dir ~= "incoming"
        if remote then g.remote = remote end
        if dir == "incoming" then
            g.incomingChevrons = true
            return { type = "dialin", address = remote }
        end
        return nil
    elseif ty == "opened" then
        g.outgoing = dir ~= "incoming"
        g.connected, g.openedAt = true, now()
        if remote then g.remote = remote end
        return { type = g.outgoing and "outgoing" or "incoming", address = remote }
    elseif ty == "closed" then
        if g.connected then g.closingAt = now() end
        g.connected, g.openedAt = false, nil
        return { type = "closed" }
    elseif ty == "entity_transit" then
        local who = d.entityName or d.entityType or "Something"
        if type(who) == "string" then who = who:gsub("^%w+:", "") end
        return { type = "traveler", direction = dir == "outgoing" and "out" or "in", name = who }
    end
    -- gdo_signal also arrives as stargate_idc_received, which is the one handled
    return nil
end

function M.dial(g, address, opts)
    local G = require("sgc.gate")
    local target = M.address(address)
    if not target then G.fail("No address") end
    local st = status(g)
    if not st then G.fail("The gate isn't complete") end
    if st.dialing or st.connected then G.fail("The gate is busy") end
    g.remote, g.engaged, g.outgoing, g.incomingChevrons = target, {}, true, false

    local ok, r = g:try("dial", target)
    if not ok then G.fail(errorText(r)) end
    if type(r) == "table" and r.success == false then G.fail(M.reason(r.code, r.message)) end

    -- the gate dials by itself; follow it chevron by chevron
    local timeout = (opts.stepTimeout or 60) + #target * 4
    local started, lit = now(), -1
    if not G.waitUntil(opts, function()
        local s = status(g)
        if not s then G.fail("Lost the gate") end
        if s.connected and not s.dialing then return true end
        if not s.dialing and not s.connected and now() - started > 2 then
            G.fail("No connection was established")
        end
        local n = math.floor((tonumber(s.dialProgress) or 0) * #target + 0.001)
        if n ~= lit then
            lit = n
            g:poll()
            if opts.onStep and n > 0 then opts.onStep(n, target:sub(n, n), #target) end
        end
        return false
    end, timeout) then
        G.fail("No connection was established")
    end
    g.outgoing = true
end

function M.close(g)
    local st = status(g)
    if st and not st.dialing and not st.connected then return true end
    local ok, r = g:try("disconnect")
    if not ok then return false, errorText(r) end
    if type(r) == "table" and r.success == false then
        if r.code == "not_connected" and st and not st.connected then return true end
        return false, M.reason(r.code, r.message)
    end
    return true
end

function M.abort(g)
    local st = status(g)
    if st and (st.dialing or st.connected) and st.direction ~= "incoming" then g:try("disconnect") end
end

local function iris(g, method)
    if g.irisLocked then return false, "The iris is locked by redstone" end
    local ok, r = g:try(method)
    if not ok then return false, errorText(r) end
    if r == false then return false, "The iris did not move" end
    return true
end

function M.openIris(g) return iris(g, "openIris") end
function M.closeIris(g) return iris(g, "closeIris") end

-- the GDO is the only way to send a code; replies to a code have nowhere to go
function M.sendMessage(g, text)
    return false, "LanteaCraft gates take iris codes from a GDO, not from a computer"
end

return M
