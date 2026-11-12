--
-- sgc.gate - one interface for every stargate a computer can talk to
--
--   Stargate Journey (Minecraft 1.20.1+): basic, crystal and advanced crystal interface
--   SGCraft (Greg Ewing's, and the 1.12.2 SGCraft 2.x): the "stargate" computer interface
--   Lantea: Stargates (1.20.1 / 1.21.1, 0.7.7.0+): a gate controller with a Power Coupler Kit
--   Just Stargate Mod (1.20.1): the stargate base block
--   Chevron Seven (1.20.1): any block of the gate ring
--
-- local gate = require("sgc.gate").find()
-- gate:poll()                       re-read the gate state
-- gate:event(e)                     feed it every event, returns a short description or nil
-- gate:dial(address, opts)          blocking, run it in its own coroutine
-- gate:close(), gate:toggleIris()
--
-- gate.state is one of IDLE, DIALING, OPEN, INCOMING, CLOSING, OFFLINE
--

local A = require("sgc.address")

local G = {}
G.__index = G

-- Chevron Seven's gate speaks the same language as Stargate Journey's crystal interface
G.SJ_INTERFACES = { "advanced_crystal_interface", "crystal_interface", "basic_interface", "chevron7_stargate" }
G.INTERFACE_NAMES = {
    advanced_crystal_interface = "Advanced crystal interface",
    crystal_interface = "Crystal interface",
    basic_interface = "Basic interface",
    chevron7_stargate = "Chevron Seven gate",
    stargate = "SGCraft interface",
    lantea = "Lantea gate controller",
    jsg = "JSG stargate",
}

-- mods that share the "stargate" peripheral type, told apart by their methods
local IMPL = {}
local function impl(mod)
    if IMPL[mod] == nil then
        local ok, m = pcall(require, "sgc." .. mod)
        IMPL[mod] = ok and m or false
    end
    return IMPL[mod] or nil
end

function G.modFor(p, ptype)
    if ptype ~= "stargate" then return "sgjourney" end
    if type(p.stargateState) == "function" then return "sgcraft" end
    if type(p.getChevronsLocked) == "function" then return "lantea" end
    if type(p.getGateStatus) == "function" then return "jsg" end
    return "sgcraft"
end

G.TYPES = {
    { match = "milky_way", id = "milky_way", name = "Milky Way", symbols = 39 },
    { match = "pegasus",   id = "pegasus",   name = "Pegasus",   symbols = 36 },
    { match = "universe",  id = "universe",  name = "Universe",  symbols = 36 },
    { match = "tollan",    id = "tollan",    name = "Tollan",    symbols = 39 },
    { match = "classic",   id = "classic",   name = "Classic",   symbols = 39 },
    { match = "chevron7",  id = "milky_way", name = "Chevron Seven", symbols = 39 },
}

-- Stargate Journey feedback codes, used when the interface gives no description
G.FEEDBACK = {
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

-- SGCraft 2.x reports errors as message keys
G.SGCRAFT_ERRORS = {
    unknownAddress = "No stargate at that address", selfBusy = "The gate is busy", selfIncomplete = "The gate isn't complete",
    targetBusy = "The gate at that address is busy", selfOutOfRange = "This gate is out of stargate range",
    targetOutOfRange = "The destination is out of stargate range", diallingItself = "A gate can't dial itself",
    selfLackChevrons = "This gate needs more chevrons for that address", targetLackChevrons = "The destination gate lacks chevrons",
    insufficientEnergy = "Not enough energy to dial", malformedAddress = "Malformed address",
    dimensionTooFar = "That dimension is out of reach", zpmNotFound = "That address needs a ZPM",
    zpmLowPower = "The ZPM lacks the power for that address", incomingConnection = "Interrupted by an incoming connection",
    irisAtDestination = "Destination blocked by its iris", cannotDialToThisGate = "That gate can't be dialed",
    cannotDialFromThisGate = "This gate can't dial out", oriOnlyOri = "An Ori supergate only connects to another supergate",
    supergateNeedsZpms = "This supergate needs more ZPMs", targetSupergateNeedsZpms = "The other supergate needs more ZPMs",
    generatedGateGone = "That gate no longer exists", accessFromDenied = "Access denied", playerAccessToDenied = "Access denied",
    accessSystemDeniedOrigin = "Access denied", accessSystemDeniedDestination = "Access denied",
}

-- readable text for an SGCraft error ("...:12: unknownAddress" -> "No stargate at that address")
function G.sgcraftError(err)
    local msg = tostring(err):gsub("^.-:%d+: ", ""):gsub("^java%.lang%.%w+: ", "")
    if G.SGCRAFT_ERRORS[msg] then return G.SGCRAFT_ERRORS[msg] end
    if msg:match("^%l%w+$") then
        msg = msg:gsub("(%u)", function(c) return " " .. c:lower() end)
        return (msg:gsub("^%l", string.upper))
    end
    return msg
end

local function now() return os.clock() end

---------------------------------------------------------------------------
-- discovery
---------------------------------------------------------------------------

-- finds a gate interface; name = peripheral name to use (optional)
function G.find(name)
    if name then
        if not peripheral.isPresent(name) then return nil end
        local t = peripheral.getType(name)
        if t ~= "stargate" then
            local ok = false
            for _, s in ipairs(G.SJ_INTERFACES) do if t == s then ok = true end end
            if not ok then return nil end
        end
        return G.new(peripheral.wrap(name), name, t)
    end
    for _, t in ipairs(G.SJ_INTERFACES) do
        local p = peripheral.find(t)
        if p then return G.new(p, peripheral.getName(p), t) end
    end
    local p = peripheral.find("stargate")
    if p then return G.new(p, peripheral.getName(p), "stargate") end
    return nil
end

-- true if the peripheral name/type could be a gate interface
function G.isInterfaceType(t)
    if t == "stargate" then return true end
    for _, s in ipairs(G.SJ_INTERFACES) do if t == s then return true end end
    return false
end

function G.new(p, name, ptype)
    local mod = G.modFor(p, ptype)
    local self = setmetatable({
        p = p, name = name, ptype = ptype,
        mod = mod,
        impl = impl(mod),
        interfaceName = G.INTERFACE_NAMES[mod ~= "sgjourney" and mod or ptype] or G.INTERFACE_NAMES[ptype] or tostring(ptype),
        -- the point of origin as the gate names it (nil: SGCraft addresses have none)
        originSymbol = (mod == "sgcraft") and nil or 0,
        energyUnit = (mod == "sgcraft") and "SU" or "FE",
        state = "IDLE", chevrons = 0, connected = false, outgoing = false,
        engaged = {},          -- symbols locked so far (for display)
        remote = nil,          -- address on the other side, if known
        lastIncoming = nil,
        openedAt = nil,        -- os.clock() when the wormhole opened (kawoosh)
        closingAt = nil,       -- os.clock() when it started closing
        iris = nil,            -- nil = no iris, otherwise percent closed (0-100)
        dialing = false,       -- our own dial is running
        incomingChevrons = false,
        typeId = "milky_way", typeName = "Stargate", symbolCount = 39,
        variant = nil, generation = nil, localAddress = nil,
        energy = nil, feedback = nil,
    }, G)
    self:detect()
    self:poll()
    return self
end

---------------------------------------------------------------------------
-- raw access
---------------------------------------------------------------------------

function G:has(method)
    return self.p ~= nil and type(self.p[method]) == "function"
end

-- calls a method, nil if it does not exist or errors
function G:call(method, ...)
    if not self:has(method) then return nil end
    local r = table.pack(pcall(self.p[method], ...))
    if r[1] then return table.unpack(r, 2, r.n) end
    return nil
end

-- calls a method, returns ok, results... or false, error message
function G:try(method, ...)
    if not self:has(method) then return false, "not supported" end
    local r = table.pack(pcall(self.p[method], ...))
    return table.unpack(r, 1, r.n)
end

function G:feedbackText(code)
    if type(code) ~= "number" then return tostring(code) end
    local recent, desc = self:call("getRecentFeedback")
    if recent == code and type(desc) == "string" and desc ~= "" then
        desc = desc:gsub("_", " ")
        return (desc:gsub("^%l", string.upper))
    end
    return G.FEEDBACK[code] or ("Feedback code " .. code)
end

---------------------------------------------------------------------------
-- gate details
---------------------------------------------------------------------------

function G:detect()
    if self.impl then return self.impl.detect(self) end
    if self.mod == "sgcraft" then
        self.typeId, self.typeName, self.symbolCount = "sgcraft", "SGCraft", 36
        self.variant = nil
        local la = self:call("localAddress")
        self.localAddress = A.fromValue(la)
        local iris = self:call("irisState")
        self.hasIris = type(iris) == "string" and iris ~= "Offline"
        self.hasZpm = self:has("zpmEnergy") -- SGCraft 2.x
        return
    end
    self.typeId, self.typeName, self.symbolCount = "milky_way", "Stargate", 39
    local t = self:call("getStargateType")
    if type(t) == "string" then
        for _, g in ipairs(G.TYPES) do
            if t:find(g.match, 1, true) then
                self.typeId, self.typeName, self.symbolCount = g.id, g.name, g.symbols
                break
            end
        end
    end
    local v = self:call("getStargateVariant")
    v = type(v) == "string" and v:gsub("^.*:", "") or nil
    if v == "" or v == "empty" then v = nil end
    self.variant = v
    self.generation = self:call("getStargateGeneration")
    local la = self:call("getLocalAddress")
    self.localAddress = A.fromValue(la)
    self.hasIris = self:has("getIris") and self:call("getIris") ~= nil and self:call("getIris") ~= false
end

-- re-reads the state from the gate (events can be missed)
function G:poll()
    if self.impl then return self.impl.poll(self) end
    if self.mod == "sgcraft" then return self:pollSGCraft() end
    local wasConnected = self.connected
    self.chevrons = self:call("getChevronsEngaged") or 0
    self.connected = self:call("isStargateConnected") == true
    local dialingOut = self:call("isStargateDialingOut")

    if self.connected then
        if dialingOut ~= nil then self.outgoing = dialingOut end
        self.state = self.outgoing and "OPEN" or "INCOMING"
        if not wasConnected and not self.openedAt then
            -- found an open wormhole: no kawoosh, it has been open for a while
            local t = self:call("getOpenTime")
            self.openedAt = now() - (type(t) == "number" and t / 20 or 10)
        end
        if not self.remote then self.remote = A.fromValue(self:call("getConnectedAddress")) end
    elseif self.dialing then
        self.state = "DIALING"
    elseif self.chevrons > 0 then
        local incoming = self.incomingChevrons
        if dialingOut ~= nil then incoming = not dialingOut end
        self.state = incoming and "INCOMING" or "DIALING"
    else
        self.state = "IDLE"
        self.remote = nil
        self.incomingChevrons = false
        self.engaged = {}
        self.openedAt = nil
    end
    if self.state == "DIALING" and self:has("getDialedAddress") then
        local d = self:call("getDialedAddress")
        if type(d) == "table" then
            local list = {}
            for i, s in ipairs(d) do list[i] = s end
            self.engaged = list
        end
    end
    if self.hasIris then
        local p = self:call("getIrisProgressPercentage")
        if type(p) == "number" then self.iris = p else self.iris = nil end
    else
        self.iris = nil
    end
    self.energy = self:call("getStargateEnergy")
    return self.state
end

local SGC_STATES = { Idle = "IDLE", Dialling = "DIALING", Opening = "OPEN", Connected = "OPEN", Closing = "CLOSING", Offline = "OFFLINE" }
local SGC_IRIS = { Open = 0, Opening = 40, Closing = 60, Closed = 100 }

function G:pollSGCraft()
    local s, chevrons, direction = self:call("stargateState")
    if type(s) ~= "string" then
        self.state = "OFFLINE"
        return self.state
    end
    self.chevrons = tonumber(chevrons) or 0
    if direction == "Outgoing" then self.outgoing = true elseif direction == "Incoming" then self.outgoing = false end
    local wasConnected = self.connected
    self.connected = (s == "Connected" or s == "Opening")
    local state = SGC_STATES[s] or "IDLE"
    if state == "DIALING" and not self.dialing and not self.outgoing then state = "INCOMING" end
    if state == "OPEN" and not self.outgoing then state = "INCOMING" end
    self.state = state
    if self.connected and not wasConnected and not self.openedAt then
        self.openedAt = s == "Opening" and now() or now() - 10
    end
    if state == "IDLE" then
        self.remote, self.engaged, self.openedAt, self.closingAt = nil, {}, nil, nil
    elseif state ~= "CLOSING" then
        local r = A.fromValue(self:call("remoteAddress"))
        if r then self.remote = r end
        if self.remote and #self.engaged < self.chevrons then
            self.engaged = {}
            for i = 1, math.min(self.chevrons, #self.remote) do self.engaged[i] = self.remote:sub(i, i) end
        end
    end
    local iris = self:call("irisState")
    self.hasIris = type(iris) == "string" and iris ~= "Offline"
    self.iris = self.hasIris and (SGC_IRIS[iris] or 50) or nil
    self.energy = self:call("energyAvailable")
    -- ZPMs (SGCraft 2.x): the lookup searches around the gate, so not every poll
    if self.hasZpm and now() - (self.zpmCheckedAt or -99) > 5 then
        self.zpmCheckedAt = now()
        local energy, count = self:call("zpmEnergy")
        self.zpmEnergy, self.zpmCount = tonumber(energy), tonumber(count)
    end
    return self.state
end

-- seconds the wormhole has been open
function G:openSeconds()
    if not self.openedAt then return nil end
    return math.max(0, now() - self.openedAt)
end

-- ring rotation in degrees (rotating gates only)
function G:rotation()
    if self.impl then return self.impl.rotation(self) end
    if self.mod ~= "sgjourney" or not self:has("getRotationDegrees") then return nil end
    local d = self:call("getRotationDegrees")
    return type(d) == "number" and d or nil
end

---------------------------------------------------------------------------
-- events
---------------------------------------------------------------------------

G.EVENTS = {
    stargate_chevron_engaged = true, stargate_incoming_wormhole = true, stargate_outgoing_wormhole = true,
    stargate_disconnected = true, stargate_reset = true, stargate_deconstructing_entity = true,
    stargate_reconstructing_entity = true, stargate_rotation_started = true, stargate_rotation_stopped = true,
    stargate_message_received = true, iris_thud = true,
    sgDialIn = true, sgDialOut = true, sgChevronEngaged = true, sgChevronUnset = true, sgStargateStateChange = true,
    sgIrisStateChange = true, sgMessageReceived = true,
    -- Lantea: Stargates
    stargate_ring_stopped = true, stargate_chevron_locked = true, stargate_incoming = true, stargate_wormhole_open = true,
    stargate_wormhole_closed = true, stargate_dial_failed = true, stargate_iris = true, stargate_iris_struck = true,
    -- Just Stargate Mod
    stargate_spin_start = true, stargate_spin_stop = true, stargate_wormhole_incoming = true,
    stargate_wormhole_open_unstable = true, stargate_wormhole_open_fully = true, stargate_wormhole_close_unstable = true,
    stargate_wormhole_close_fully = true, stargate_attempt_open_failed = true, stargate_event_horizon_traveler = true,
    stargate_iris_state_changed = true, stargate_iris_hit = true,
}

local function eventAddress(e, offset)
    for i = offset, e.n or #e do
        local a = A.fromValue(e[i])
        if a then return a end
    end
end

-- feed every event; returns { type = ..., ... } for gate events of this gate, nil otherwise
function G:event(e)
    local name = e[1]
    if not G.EVENTS[name] then return nil end
    -- the first argument is the peripheral name (Stargate Journey 0.6.x+ and SGCraft)
    local o = 2
    if type(e[2]) == "string" then
        if e[2] ~= self.name then return nil end
        o = 3
    end
    if self.impl then
        local info = self.impl.event(self, name, e, o)
        self:poll()
        return info
    end
    local info

    if name == "stargate_chevron_engaged" then
        local incoming, symbol
        local n = e[o]
        for i = o, e.n or #e do
            if type(e[i]) == "boolean" then
                incoming = e[i]
                if type(e[i + 1]) == "number" then symbol = e[i + 1] end
            end
        end
        if incoming ~= nil then self.incomingChevrons = incoming end
        if incoming then self.outgoing = false end
        if type(n) == "number" then
            self.chevrons = n
            if symbol ~= nil then self.engaged[n] = symbol end
            for i = n + 1, #self.engaged do self.engaged[i] = nil end
        end
        info = { type = "chevron", n = n, symbol = symbol, incoming = incoming == true }
    elseif name == "stargate_incoming_wormhole" then
        self.outgoing, self.connected = false, true
        self.openedAt = now()
        self.remote = eventAddress(e, o)
        if self.remote then self.lastIncoming = self.remote end
        info = { type = "incoming", address = self.remote }
    elseif name == "stargate_outgoing_wormhole" then
        self.outgoing, self.connected = true, true
        self.openedAt = now()
        self.remote = eventAddress(e, o) or self.remote
        info = { type = "outgoing", address = self.remote }
    elseif name == "stargate_disconnected" or name == "stargate_reset" then
        local code, desc = e[o], e[o + 1]
        local text = (type(desc) == "string" and desc ~= "") and desc:gsub("_", " ") or (type(code) == "number" and self:feedbackText(code)) or nil
        if self.connected then self.closingAt = now() end
        self.outgoing, self.remote, self.incomingChevrons, self.connected = false, nil, false, false
        self.engaged, self.openedAt = {}, nil
        info = { type = name == "stargate_disconnected" and "closed" or "reset", code = code, reason = text,
                 error = type(code) == "number" and code < 0 }
    elseif name == "stargate_deconstructing_entity" then
        info = { type = "traveler", direction = "out", name = e[o + 1] }
    elseif name == "stargate_reconstructing_entity" then
        info = { type = "traveler", direction = "in", name = e[o + 1] }
    elseif name == "stargate_rotation_started" or name == "stargate_rotation_stopped" then
        info = { type = "rotation", started = name == "stargate_rotation_started" }
    elseif name == "iris_thud" then
        info = { type = "thud", name = e[o + 1] }
    elseif name == "stargate_message_received" or name == "sgMessageReceived" then
        local parts = {}
        for i = o, e.n or #e do parts[#parts + 1] = tostring(e[i]) end
        info = { type = "message", text = table.concat(parts, " ") }

    -- SGCraft
    elseif name == "sgDialIn" or name == "sgDialOut" then
        self.outgoing = name == "sgDialOut"
        self.remote = A.fromValue(e[o])
        self.engaged = {}
        if not self.outgoing and self.remote then self.lastIncoming = self.remote end
        info = { type = self.outgoing and "dialout" or "dialin", address = self.remote }
    elseif name == "sgChevronEngaged" then
        local n, symbol = e[o], e[o + 1]
        if type(n) == "number" then
            self.chevrons = n
            self.engaged[n] = symbol
        end
        info = { type = "chevron", n = n, symbol = symbol, incoming = not self.outgoing }
    elseif name == "sgChevronUnset" then
        -- SGCraft 2.x: a symbol was taken back on the DHD
        local n = e[o]
        if type(n) == "number" then
            self.chevrons = n
            for i = n + 1, #self.engaged do self.engaged[i] = nil end
        end
        info = { type = "chevron", n = n, unset = true, incoming = not self.outgoing }
    elseif name == "sgStargateStateChange" then
        local new = e[o]
        if new == "Dialling" then
            -- SGCraft 2.x sends no sgDialIn/sgDialOut, but reports the direction while dialing
            self.engaged, self.openedAt, self.closingAt = {}, nil, nil
            local _, _, direction = self:call("stargateState")
            if direction == "Incoming" and not self.dialing then
                self.outgoing = false
                self.remote = A.fromValue(self:call("remoteAddress"))
                if self.remote then self.lastIncoming = self.remote end
                info = { type = "dialin", address = self.remote }
            elseif direction == "Outgoing" then
                self.outgoing = true
                info = { type = "dialout", address = self.remote }
            else
                info = { type = "state", state = new }
            end
        elseif new == "Opening" or (new == "Connected" and not self.openedAt) then
            self.connected = true
            self.openedAt = now()
            info = { type = self.outgoing and "outgoing" or "incoming", address = self.remote }
        elseif new == "Closing" then
            self.closingAt = now()
            info = { type = "closed" }
        elseif new == "Idle" then
            self.connected, self.engaged, self.openedAt = false, {}, nil
            info = { type = "idle" }
        else
            info = { type = "state", state = new }
        end
    elseif name == "sgIrisStateChange" then
        info = { type = "iris", state = e[o] }
    end

    self:poll()
    return info
end

---------------------------------------------------------------------------
-- actions
---------------------------------------------------------------------------

function G:close()
    if self.impl then return self.impl.close(self) end
    if self.mod == "sgcraft" then
        local ok, err = self:try("disconnect")
        return ok, not ok and G.sgcraftError(err) or nil
    end
    self:call("endRotation")
    if self:has("isChevronOpen") and self:call("isChevronOpen") then self:call("closeChevron") end
    return self:call("disconnectStargate") ~= nil
end

function G:openIris()
    if self.impl and self.impl.openIris then return self.impl.openIris(self) end
    return self:try("openIris")
end

function G:closeIris()
    if self.impl and self.impl.closeIris then return self.impl.closeIris(self) end
    return self:try("closeIris")
end

function G:toggleIris()
    if not self.hasIris then return false, "No iris installed on this gate" end
    self:poll()
    if self.iris and self.iris > 0 then return self:openIris() end
    return self:closeIris()
end

---------------------------------------------------------------------------
-- dialing (blocking - run it in its own coroutine)
---------------------------------------------------------------------------

local Abort = {}
local Fail = {}

-- opts: fast, symbolDelay, chevronDelay, stepTimeout, connectTimeout,
--       abort = function() return true to stop end,
--       onStep = function(index, symbol, total) end
-- returns true, or false + reason ("aborted" when stopped)
function G:dial(address, opts)
    opts = opts or {}
    local dialable, why = A.dialableBy(address, self.mod)
    if not dialable then return false, why end

    self.dialing = true
    local fn = self.impl and self.impl.dial or (self.mod == "sgcraft" and self.dialSGCraft or self.dialJourney)
    local ok, err = pcall(fn, self, address, opts)
    self.dialing = false
    if ok then return true end
    if err == "Terminated" then error(err, 0) end
    if type(err) == "table" and err[1] == Abort then
        self:abortCleanup()
        return false, "aborted"
    end
    local reason = (type(err) == "table" and err[1] == Fail) and err[2] or tostring(err)
    if not self.connected then self:close() end
    return false, reason
end

function G:abortCleanup()
    if self.impl then return self.impl.abort(self) end
    if self.mod == "sgcraft" then
        self:try("disconnect")
        return
    end
    self:call("endRotation")
    if self:has("isChevronOpen") and self:call("isChevronOpen") then self:call("closeChevron") end
    if self:call("isStargateConnected") ~= true then self:call("disconnectStargate") end
end

local function fail(reason) error({ Fail, reason }, 0) end
G.fail = fail

local function waitUntil(opts, predicate, timeout)
    local deadline = now() + timeout
    while not predicate() do
        if opts.abort and opts.abort() then error({ Abort }, 0) end
        if now() > deadline then return false end
        sleep(0.1)
    end
    return true
end

local function pause(opts, t)
    if t and t > 0 then sleep(t) end
    if opts.abort and opts.abort() then error({ Abort }, 0) end
end
G.waitUntil, G.pause = waitUntil, pause

function G:checkFeedback(fb, allowed)
    if type(fb) ~= "number" or fb >= 0 then return end
    for _, a in ipairs(allowed or {}) do
        if fb == a then return end
    end
    fail(self:feedbackText(fb))
end

function G:dialJourney(address, opts)
    local list = A.strip(address)
    list[#list + 1] = 0
    local stepTimeout = opts.stepTimeout or 60
    local symbolDelay = opts.fast and 0 or (opts.symbolDelay or 0.5)
    local chevronDelay = opts.fast and 0 or (opts.chevronDelay or 0.4)

    local openName = self:has("openChevron") and "openChevron" or (self:has("raiseChevron") and "raiseChevron")
    local closeName = self:has("closeChevron") and "closeChevron" or (self:has("lowerChevron") and "lowerChevron")
    local canRotate = self:has("rotateClockwise") and self:has("isCurrentSymbol") and openName and closeName
    local useEngage = self:has("engageSymbol") and (not canRotate or opts.fast)
    if not useEngage and not canRotate then fail("This interface can't dial this gate (use a crystal interface)") end

    -- start from a clean gate
    if self:has("isChevronOpen") and self:call("isChevronOpen") then self:call(closeName) end
    if (self:call("getChevronsEngaged") or 0) > 0 then
        self:call("disconnectStargate")
        sleep(0.5)
    end
    self.engaged = {}

    local function chevronsAtLeast(n)
        return function()
            self.chevrons = self:call("getChevronsEngaged") or 0
            return self.chevrons >= n
        end
    end

    for i, symbol in ipairs(list) do
        pause(opts)
        local last = (i == #list)
        if opts.onStep then opts.onStep(i, symbol, #list) end
        if useEngage then
            self:checkFeedback(self:call("engageSymbol", symbol))
            if not last then
                if not waitUntil(opts, chevronsAtLeast(i), stepTimeout) then fail("Chevron " .. i .. " did not lock") end
                pause(opts, symbolDelay)
            end
        else
            if not self:call("isCurrentSymbol", symbol) then
                if i % 2 == 0 then
                    self:call("rotateClockwise", symbol)
                else
                    self:call("rotateAntiClockwise", symbol)
                end
                if not waitUntil(opts, function() return self:call("isCurrentSymbol", symbol) end, stepTimeout) then
                    self:call("endRotation")
                    fail("The ring did not reach symbol " .. symbol)
                end
            end
            pause(opts, chevronDelay)
            self:checkFeedback(self:call(openName), { -26 })
            pause(opts, chevronDelay)
            self:checkFeedback(self:call(closeName), { -2, -27 })
            if not last then
                if not waitUntil(opts, chevronsAtLeast(i), 5) then fail("Chevron " .. i .. " did not lock") end
                pause(opts, chevronDelay)
            end
        end
    end

    -- point of origin encoded, wait for the wormhole
    if not waitUntil(opts, function() return self:call("isStargateConnected") == true end, opts.connectTimeout or 10) then
        local code = self:call("getRecentFeedback")
        fail(type(code) == "number" and code < 0 and self:feedbackText(code) or "No connection was established")
    end
    self.outgoing = true
    self.remote = A.strip(address)
end

function G:dialSGCraft(address, opts)
    if self:call("stargateState") ~= "Idle" then fail("The gate is busy") end
    self.outgoing, self.remote, self.engaged = true, address, {}
    local ok, err = self:try("dial", address)
    if not ok then fail(G.sgcraftError(err)) end
    local total = #address
    local seen = 0
    local done = waitUntil(opts, function()
        local s, chevrons = self:call("stargateState")
        chevrons = tonumber(chevrons) or 0
        while seen < chevrons and seen < total do
            seen = seen + 1
            if opts.onStep then opts.onStep(seen, address:sub(seen, seen), total) end
        end
        if s == "Idle" then fail("The gate stopped dialing") end
        return s == "Connected" or s == "Opening"
    end, opts.stepTimeout or 60)
    if not done then fail("No connection was established") end
end

return G
