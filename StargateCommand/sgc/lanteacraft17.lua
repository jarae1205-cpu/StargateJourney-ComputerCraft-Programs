--
-- sgc.lanteacraft17 - LanteaCraft for Minecraft 1.7.10 (by Michiyo and AfterLifeLochie, the
-- 1.7.10 releases of 2014-2015, before the mod's rewrite)
--
-- ComputerCraft: LanteaCraft's "ComputerCraft Adapter" block, placed against the gate's base block,
-- is a "stargate" peripheral (it must touch no other LanteaCraft block; against the DHD, the
-- "Stargate Controller", it is a "stargate_controller", which can't dial).
-- OpenComputers: an Adapter block next to the gate's base block gives a "stargate" component.
--
-- Methods: dial(address) (connect is the same), disconnect(), isConnected() (true while the gate
-- dials or is open), isDialing(), getAddress(), isComplete(), hasFuel(), getInterfaceVersion();
-- OpenComputers adds isBusy() and isValid(). Nothing tells the direction or the other gate's
-- address, so both come from the events.
--
-- An address is 7 or 9 glyphs from A-Z, 0-9, "-" and "+": 7 for a gate in the same dimension,
-- 9 to reach another one. One dial() call dials the whole address: 2 seconds per chevron, half a
-- second between them, a 1 second kawoosh, and the wormhole stays open 5 minutes unless it is
-- closed (either end can close it). A dial to an address with no gate runs through all its
-- chevrons and then gives up. There is no iris a computer can move, no GDO and no messages.
--
-- Events, without the peripheral name:
--   sgOutgoing (address)   as each chevron of an outgoing dial starts
--   sgIncoming (glyph)     as each chevron of an incoming dial starts, with that chevron's glyph
--   sgChevronEncode (n)    chevron n locked
--   sgWormholeOpening, sgWormholeStable (OpenComputers only), sgWormholeClosing, sgIdle (true)
--
-- Used by sgc.gate; the functions take the gate object.
--

local M = {}

local function now() return os.clock() end

-- the gate's events, which carry no peripheral name
M.EVENTS = {
    sgOutgoing = true, sgIncoming = true, sgChevronEncode = true, sgWormholeOpening = true,
    sgWormholeStable = true, sgWormholeClosing = true, sgIdle = true,
}

-- the gate's own error messages, made readable
M.ERRORS = {
    ["Stargate addresses must be 7 or 9 characters"] = "LanteaCraft addresses have 7 or 9 glyphs",
    ["Stargate cannot connect to itself"] = "A gate can't dial itself",
    ["Stargate cannot dial now"] = "The gate can't dial that address",
    ["Stargate cannot be closed from this end"] = "This gate can't close the wormhole from this end",
    ["Stargate cannot be disconnected"] = "This gate can't close the wormhole from this end",
    ["Stargate is not connected"] = "No wormhole to close",
}

local function errorText(err)
    local msg = tostring(err):gsub("^.-:%d+: ", ""):gsub("^java%.lang%.%w+: ", ""):gsub("%.$", "")
    if msg == "" or msg == "nil" then return "The gate refused" end
    return M.ERRORS[msg] or msg
end
M.errorText = errorText

-- a LanteaCraft address: every glyph kept, "-" and "+" included
function M.address(v)
    if type(v) ~= "string" then return nil end
    local s = v:upper():gsub("%s", "")
    if s == "" or not s:find("^[A-Z0-9%-%+]+$") then return nil end
    return s
end

-- nil if the address can be dialed, otherwise why not
function M.check(address)
    local s = M.address(address)
    if not s then return "LanteaCraft addresses are glyphs from A-Z, 0-9, - and +" end
    if #s ~= 7 and #s ~= 9 then return "LanteaCraft (1.7.10) addresses have 7 or 9 glyphs" end
    return nil
end

-- true while the gate dials or is open, false when idle, nil if the gate can't be read
local function busy(g)
    local b = g:call("isConnected")
    if b == nil then b = g:call("isBusy") end
    if type(b) ~= "boolean" then return nil end
    return b
end

local function dialing(g)
    return g:call("isDialing") == true
end

-- the glyphs locked so far, for the ring picture
local function setEngaged(g)
    local list = {}
    local a = g.remote or g.incomingGlyphs
    if a then
        for i = 1, math.min(g.chevrons or 0, #a) do list[i] = a:sub(i, i) end
    end
    g.engaged = list
end

local function reset(g)
    g.remote, g.engaged, g.openedAt, g.chevrons = nil, {}, nil, 0
    g.incomingChevrons, g.incomingGlyphs, g.lcPhase, g.lcClosing = false, nil, nil, false
end

function M.detect(g)
    -- "-" is a glyph here, so addresses are shown and read without SGCraft's dashes
    require("sgc.address").plainLetters = true
    -- drawn like an SGCraft gate: a ring of letter glyphs with no point of origin
    g.typeId, g.typeName, g.symbolCount = "sgcraft", "LanteaCraft", 38
    g.variant = nil
    g.originSymbol = nil
    g.energyUnit = ""
    g.hasIris = false
    g.localAddress = M.address(g:call("getAddress"))
    g.interfaceVersion = g:call("getInterfaceVersion")
    g.namelessEvents = M.EVENTS
end

function M.poll(g)
    local b = busy(g)
    if b == nil then
        g.state = "OFFLINE"
        return g.state
    end
    local wasConnected = g.connected
    g.complete = g:call("isComplete")
    if not b then
        g.connected = false
        -- like SGCraft's Offline: the gate isn't built (or its interface lost it)
        g.state = g.complete == false and "OFFLINE" or "IDLE"
        if not g.dialing then reset(g) end
    elseif dialing(g) then
        g.connected = false
        local incoming = g.lcPhase == "incoming" or (not g.dialing and not g.outgoing)
        g.state = incoming and "INCOMING" or "DIALING"
    else
        -- the wormhole is forming, open or closing; the gate doesn't say which way it goes
        g.connected = true
        if not wasConnected and not g.openedAt then g.openedAt = now() - 10 end
        if g.lcClosing then
            g.state = "CLOSING"
        else
            g.state = g.outgoing and "OPEN" or "INCOMING"
        end
        if g.remote and #g.remote > 0 then g.chevrons = #g.remote end
    end
    if g.state ~= "IDLE" and g.state ~= "OFFLINE" then setEngaged(g) end
    g.iris, g.energy = nil, nil
    return g.state
end

function M.rotation(g) return nil end

function M.event(g, name, e, o)
    local v = e[o]
    if name == "sgOutgoing" then
        -- sent again as every chevron starts; only the first one is news
        local first = g.lcPhase ~= "outgoing"
        g.lcPhase, g.outgoing, g.incomingChevrons, g.lcClosing = "outgoing", true, false, false
        g.remote = M.address(v) or g.remote
        if first then
            g.chevrons, g.engaged, g.openedAt = 0, {}, nil
            return { type = "dialout", address = g.remote }
        end
        return nil
    elseif name == "sgIncoming" then
        -- one glyph of the caller's address with each chevron: put the address together
        local first = g.lcPhase ~= "incoming"
        if first then
            g.incomingGlyphs, g.chevrons, g.engaged, g.openedAt = "", 0, {}, nil
            g.remote = nil
        end
        g.lcPhase, g.outgoing, g.incomingChevrons, g.lcClosing = "incoming", false, true, false
        local glyph = M.address(v)
        if glyph and #glyph == 1 then g.incomingGlyphs = (g.incomingGlyphs or "") .. glyph end
        if first then return { type = "dialin", address = nil } end
        return nil
    elseif name == "sgChevronEncode" then
        local n = tonumber(v)
        if not n then return nil end
        g.chevrons = n
        setEngaged(g)
        local a = g.remote or g.incomingGlyphs
        return { type = "chevron", n = n, symbol = a and a:sub(n, n) or nil, incoming = g.lcPhase == "incoming" }
    elseif name == "sgWormholeOpening" then
        g.connected, g.openedAt, g.lcClosing = true, now(), false
        if g.lcPhase == "incoming" then
            g.outgoing = false
            local caller = M.address(g.incomingGlyphs)
            if caller and (#caller == 7 or #caller == 9) then
                g.remote = caller
                g.lastIncoming = caller
            end
            return { type = "incoming", address = g.remote }
        end
        g.outgoing = true
        return { type = "outgoing", address = g.remote }
    elseif name == "sgWormholeClosing" then
        if g.connected then g.closingAt = now() end
        g.lcClosing = true
        return { type = "closed" }
    elseif name == "sgIdle" then
        local wasOpen = g.connected or g.lcClosing
        local phase = g.lcPhase
        reset(g)
        g.connected = false
        -- a dial that ended without a wormhole: no gate answered, or it was called off
        if phase and not wasOpen then return { type = "closed", reason = "No wormhole was formed" } end
        return { type = "idle" }
    end
    -- sgWormholeStable: the wormhole was already reported when it formed
    return nil
end

function M.dial(g, address, opts)
    local G = require("sgc.gate")
    local why = M.check(address)
    if why then G.fail(why) end
    local target = M.address(address)
    -- the ComputerCraft Adapter's own check for this never matches
    local here = g.localAddress or M.address(g:call("getAddress"))
    if here and (target == here or target == here:sub(1, 7)) then G.fail("A gate can't dial itself") end
    local b = busy(g)
    if b == nil then G.fail("Lost the gate") end
    if b then G.fail("The gate is busy") end
    if g:call("isComplete") == false then G.fail("The gate isn't complete") end
    g.remote, g.engaged, g.outgoing, g.incomingChevrons = target, {}, true, false
    g.chevrons, g.lcPhase, g.lcClosing, g.incomingGlyphs = 0, "outgoing", false, nil

    local ok, r = g:try("dial", target)
    if not ok then G.fail(errorText(r)) end
    if r == false then G.fail("The gate can't dial that address") end

    -- the gate dials by itself; the chevrons are counted by sgChevronEncode events
    local started, lit = now(), 0
    local timeout = (opts.stepTimeout or 60) + #target * 4
    if not G.waitUntil(opts, function()
        local nowBusy = busy(g)
        if nowBusy == nil then G.fail("Lost the gate") end
        if not nowBusy then
            -- the gate dialed every chevron and gave up: no gate there, or it was busy
            if now() - started > 1 then G.fail("No gate answered at that address") end
            return false
        end
        local n = math.min(g.chevrons or 0, #target)
        while lit < n do
            lit = lit + 1
            if opts.onStep then opts.onStep(lit, target:sub(lit, lit), #target) end
        end
        return not dialing(g)
    end, timeout) then
        G.fail("No connection was established")
    end
    while lit < #target do
        lit = lit + 1
        if opts.onStep then opts.onStep(lit, target:sub(lit, lit), #target) end
    end
    g.chevrons, g.outgoing, g.remote = #target, true, target
end

function M.close(g)
    local b = busy(g)
    if b == false then return true end
    local ok, r = g:try("disconnect")
    if not ok then
        -- the gate went idle meanwhile
        if busy(g) == false then return true end
        return false, errorText(r)
    end
    if r == false then return false, "The gate refused to close" end
    return true
end

function M.abort(g)
    if busy(g) then g:try("disconnect") end
end

function M.openIris(g) return false, "LanteaCraft 1.7.10 gates have no iris a computer can move" end
function M.closeIris(g) return false, "LanteaCraft 1.7.10 gates have no iris a computer can move" end

function M.sendMessage(g, text)
    return false, "LanteaCraft 1.7.10 gates can't send messages"
end

return M
