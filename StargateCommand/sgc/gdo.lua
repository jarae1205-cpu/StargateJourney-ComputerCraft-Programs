--
-- sgc.gdo - the GDO, a traveller's iris code transmitter, and the relay at the gate
--
-- A GDO is a pocket computer running the gdo program. It can't reach through a
-- wormhole by itself: it radios the computer at the gate it stands next to (the
-- relay), and that computer sends the code through the open wormhole with the gate's
-- message function, the way the dialing computer sends an address book entry's code
-- (see sgc.idc). The answer from the other side, "IDC:ACCEPTED SG-1" or
-- "IDC:REJECTED", comes back the same way and the relay radios it to the GDO.
--
-- The Gate Room is a relay when its computer has a wireless or ender modem, and
-- "gdo relay" makes any computer at a gate one.
--
-- Radio: relays listen on modem channel 2427; they answer on the GDO's own channel.
-- Every message is a table { sgcGdo = 1, type = ..., ... }:
--   GDO   -> relays  { type = "ping" }                              who is there?
--   GDO   -> relay   { type = "code", to = <relay id>, code = "600", seq = n }
--   relay -> GDO     { type = "status", relay = <id>, label, state, outgoing, connected, canSend, why }
--   relay -> GDO     { type = "sent", seq = n }  or  { type = "failed", seq = n, why = "..." }
--   relay -> GDO     { type = "answer", result = "accepted" | "rejected", name = "SG-1" }
--

local IDC = require("sgc.idc")

local M = {}

M.CHANNEL = 2427
M.MARK = 1
-- seconds a relay waits for the other side to answer a code it sent
M.ANSWER_TIME = 15

-- a wireless or ender modem (the radio), or nil
function M.findRadio()
    return peripheral.find("modem", function(_, m)
        return type(m.isWireless) ~= "function" or m.isWireless()
    end)
end

function M.message(t)
    t.sgcGdo = M.MARK
    return t
end

-- the GDO message in a modem_message event, or nil
function M.read(e, channel)
    if e[1] ~= "modem_message" then return nil end
    if channel and e[3] ~= channel then return nil end
    local msg = e[5]
    if type(msg) ~= "table" or msg.sgcGdo ~= M.MARK or type(msg.type) ~= "string" then return nil end
    return msg, e[4], e[6] -- message, reply channel, distance (nil from another dimension)
end

---------------------------------------------------------------------------
-- the relay, on the computer at the gate
---------------------------------------------------------------------------

local Relay = {}
Relay.__index = Relay

-- getGate: a function that returns the program's gate object (sgc.gate), or nil.
-- Returns nil and a reason if the computer has no radio.
function M.newRelay(getGate, radio)
    radio = radio or M.findRadio()
    if not radio then return nil, "No wireless or ender modem" end
    radio.open(M.CHANNEL)
    local label = os.getComputerLabel()
    return setmetatable({
        getGate = getGate,
        radio = radio,
        radioName = peripheral.getName(radio),
        id = os.getComputerID(),
        label = label,
        pending = nil, -- { channel, code, untilClock }
    }, Relay)
end

-- the radio was removed: true if it was this relay's
function Relay:detached(name)
    return name == self.radioName
end

function Relay:close()
    pcall(self.radio.close, M.CHANNEL)
end

function Relay:send(channel, msg)
    pcall(self.radio.transmit, channel, M.CHANNEL, M.message(msg))
end

-- what the relay tells a GDO about its gate
function Relay:status()
    local g = self.getGate()
    local label = self.label
    if not g then
        return { type = "status", relay = self.id, label = label or ("Computer " .. self.id),
                 state = "OFFLINE", connected = false, outgoing = false, canSend = false, why = "No stargate interface" }
    end
    if not label then
        label = g.localAddress and ("Gate " .. tostring(g.localAddress)) or ("Gate #" .. self.id)
    end
    local canSend, why = g:canSendMessages()
    return {
        type = "status", relay = self.id, label = label,
        state = g.state, outgoing = g.outgoing == true, connected = g.connected == true,
        canSend = canSend, why = why,
    }
end

-- feed it every event. Returns nil, or what happened for the program's screen:
--   { kind = "sent", code = "600" } | { kind = "failed", code = "600", why = "..." }
function Relay:event(e)
    if e[1] == "modem_message" and e[2] ~= self.radioName then return nil end
    local msg, reply = M.read(e, M.CHANNEL)
    if not msg or type(reply) ~= "number" then return nil end
    if msg.type == "ping" then
        self:send(reply, self:status())
    elseif msg.type == "code" and msg.to == self.id then
        local code = IDC.clean(msg.code)
        local why
        local g = self.getGate()
        if not code then
            why = "Not a code"
        elseif not g then
            why = "No stargate interface"
        elseif not g.connected then
            why = "No wormhole"
        else
            local can, cant = g:canSendMessages()
            if not can then
                why = cant
            else
                local ok, err = g:sendMessage(IDC.message(code))
                if not ok then why = tostring(err or "The code did not go through") end
            end
        end
        if why then
            self:send(reply, { type = "failed", seq = msg.seq, why = why })
            return { kind = "failed", code = code or tostring(msg.code), why = why }
        end
        self.pending = { channel = reply, code = code, untilClock = os.clock() + M.ANSWER_TIME }
        self:send(reply, { type = "sent", seq = msg.seq })
        return { kind = "sent", code = code }
    end
    return nil
end

-- the gate brought an answer to a code (kind and value from sgc.idc's parse).
-- Returns true if a GDO was waiting for it.
function Relay:answer(kind, value)
    local p = self.pending
    if not p then return false end
    self.pending = nil
    if os.clock() > p.untilClock then return false end
    if kind ~= "accepted" and kind ~= "rejected" then return false end
    self:send(p.channel, { type = "answer", result = kind, name = value })
    return true
end

-- the wormhole closed: a waiting GDO hears no more
function Relay:closed()
    local p = self.pending
    if not p then return end
    self.pending = nil
    self:send(p.channel, { type = "failed", why = "The wormhole closed" })
end

M.Relay = Relay

return M
