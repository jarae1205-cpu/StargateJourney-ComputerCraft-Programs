--
--   GDO - a traveller's iris code transmitter for a pocket computer
--
--   Stand by the gate with the wormhole open, punch in your code and press SEND.
--   The code goes to the computer at the gate (the relay), through the wormhole
--   to the gate room on the other side, and the GDO shows their answer: the iris
--   opens for a trusted code, or stays shut.
--
--   gdo                 the GDO, on an advanced pocket computer with a wireless or ender modem
--   gdo send <code>     send a code from the command line and print the answer
--   gdo relay           run the relay on the computer at a gate (it needs a wireless
--                       or ender modem and the gate interface)
--
--   The Gate Room is a relay by itself when its computer has a wireless or ender
--   modem; "gdo relay" is for gates whose computer runs something else or nothing.
--   On an advanced computer it can run in the background next to another program:
--   bg gdo relay
--
--   The gate room you are calling trusts codes with the idc program (idc add 600 SG-1).
--

local VERSION = "1.0"

local CONFIG = {
    -- the code the GDO remembers (the last one sent)
    file = "gdo.cfg",
    -- seconds between looks for the gate
    pingEvery = 2,
    -- seconds to collect answers from the gates in range
    listenTime = 0.4,
    -- seconds for the gate's computer to say it sent the code
    replyTime = 3,
    -- seconds to wait for the other side to answer
    answerTime = 15,
    -- key clicks and answer tones on a pocket computer with a speaker
    sounds = true,
}

local GDO = require("sgc.gdo")
local IDC = require("sgc.idc")

local args = { ... }

---------------------------------------------------------------------------
-- the radio side of the GDO (shared by the screen and "gdo send")
---------------------------------------------------------------------------

local Client = {}
Client.__index = Client

function Client.new(radio)
    local self = setmetatable({
        radio = radio,
        radioName = peripheral.getName(radio),
        -- each GDO answers on a channel of its own
        channel = 30000 + (os.getComputerID() % 30000),
        seq = 0,
    }, Client)
    radio.open(self.channel)
    return self
end

function Client:close()
    pcall(self.radio.close, self.channel)
end

function Client:transmit(msg)
    self.radio.transmit(GDO.CHANNEL, self.channel, GDO.message(msg))
end

function Client:ping()
    self:transmit({ type = "ping" })
end

function Client:sendCode(relayId, code)
    self.seq = self.seq + 1
    self:transmit({ type = "code", to = relayId, code = code, seq = self.seq })
    return self.seq
end

-- a modem event for this GDO, or nil: msg, distance
function Client:read(e)
    if e[1] ~= "modem_message" or e[2] ~= self.radioName then return nil end
    local msg, _, distance = GDO.read(e, self.channel)
    return msg, distance
end

-- picks the gate to talk to from the statuses heard: the nearest one with a
-- wormhole open, else the nearest one. Gates in another dimension (no distance) are out of reach.
local function bestRelay(found)
    local best
    for _, s in pairs(found) do
        if s.distance then
            if not best then
                best = s
            elseif (s.connected and not best.connected) or
                   (s.connected == best.connected and s.distance < best.distance) then
                best = s
            end
        end
    end
    return best
end

local function remember(code)
    local f = fs.open(CONFIG.file, "w")
    if f then
        f.write(textutils.serialize({ code = code }))
        f.close()
    end
end

local function remembered()
    if not fs.exists(CONFIG.file) then return nil end
    local f = fs.open(CONFIG.file, "r")
    if not f then return nil end
    local data = textutils.unserialize(f.readAll())
    f.close()
    return type(data) == "table" and IDC.clean(data.code) or nil
end

local function stateText(s)
    if not s then return "No gate in range" end
    if s.state == "OFFLINE" then return s.why or "The gate's computer has no gate" end
    if s.connected then
        return s.outgoing and "Wormhole open" or "Incoming wormhole"
    end
    if s.state == "DIALING" then return "The gate is dialing" end
    if s.state == "INCOMING" then return "A gate is dialing in" end
    return "No wormhole"
end

---------------------------------------------------------------------------
-- the relay, on the computer at a gate
---------------------------------------------------------------------------

local function runRelay()
    local Gate = require("sgc.gate")
    local gate = Gate.find()
    local relay, why = GDO.newRelay(function() return gate end)
    local logLines = {}

    local function log(text, color)
        local t = textutils.formatTime(os.time(), true)
        table.insert(logLines, 1, { text = t .. " " .. text, color = color or colors.white })
        while #logLines > 40 do table.remove(logLines) end
    end

    local function draw()
        local w, h = term.getSize()
        term.setBackgroundColor(colors.black)
        term.clear()
        term.setCursorPos(1, 1)
        term.setBackgroundColor(colors.orange)
        term.setTextColor(colors.black)
        term.clearLine()
        term.write((" GDO RELAY v" .. VERSION):sub(1, w))
        term.setBackgroundColor(colors.black)
        local function line(y, label, value, color)
            term.setCursorPos(2, y)
            term.setTextColor(colors.lightGray)
            term.write(label)
            term.setTextColor(color or colors.white)
            term.write(tostring(value):sub(1, math.max(0, w - #label - 2)))
        end
        line(3, "Radio   ", relay and ("channel " .. GDO.CHANNEL) or (why or "none"), relay and colors.lime or colors.red)
        if gate then
            gate:poll()
            local can, cant = gate:canSendMessages()
            line(4, "Gate    ", gate.interfaceName .. (gate.localAddress and (" " .. tostring(gate.localAddress)) or ""))
            local st = relay and relay:status() or { state = gate.state, connected = gate.connected, outgoing = gate.outgoing }
            line(5, "State   ", stateText(st), gate.connected and colors.lightBlue or colors.lightGray)
            line(6, "Codes   ", can and "can go through" or cant, can and colors.lime or colors.orange)
        else
            line(4, "Gate    ", "no stargate interface", colors.red)
        end
        term.setCursorPos(2, 8)
        term.setTextColor(colors.gray)
        term.write(("Codes from GDOs nearby"):sub(1, w - 2))
        for i, l in ipairs(logLines) do
            local y = 8 + i
            if y > h - 1 then break end
            term.setCursorPos(2, y)
            term.setTextColor(l.color)
            term.write(l.text:sub(1, w - 2))
        end
        term.setCursorPos(1, h)
        term.setTextColor(colors.gray)
        term.write(("Hold Ctrl+T to stop"):sub(1, w))
    end

    if relay then log("Listening for GDOs", colors.lime) end

    -- A call to the gate waits for the server, and events that come in meanwhile
    -- would be lost to the task making it. One task only collects events (it never
    -- calls the gate) and the other works through them in order.
    local queue = {}
    local function listener()
        while true do
            local e = table.pack(os.pullEventRaw())
            if e[1] ~= "gdo_relay_wake" then
                queue[#queue + 1] = e
                os.queueEvent("gdo_relay_wake")
            end
        end
    end
    local function nextEvent()
        while #queue == 0 do os.pullEventRaw("gdo_relay_wake") end
        return table.remove(queue, 1)
    end

    local poll = os.startTimer(1)
    local function worker()
        draw()
        while true do
            local e = nextEvent()
            local name = e[1]
            if name == "terminate" then break end
            local redraw = false
            if gate then
                local info = gate:event(e)
                if info then
                    redraw = true
                    if info.type == "message" and relay then
                        local kind, value = IDC.parse(info.text)
                        if (kind == "accepted" or kind == "rejected") and relay:answer(kind, value) then
                            log("Answer " .. kind .. (value and (": " .. value) or "") .. ", told the GDO",
                                kind == "accepted" and colors.lime or colors.red)
                        end
                    elseif (info.type == "closed" or info.type == "reset") and relay then
                        relay:closed()
                    end
                end
            end
            if relay then
                local r = relay:event(e)
                if r then
                    redraw = true
                    if r.kind == "sent" then log("Code " .. r.code .. " sent through the gate", colors.lightBlue)
                    else log("Code " .. tostring(r.code) .. ": " .. r.why, colors.orange) end
                end
            end
            if name == "timer" and e[2] == poll then
                poll = os.startTimer(1)
                redraw = true
            elseif name == "peripheral" then
                if not gate and Gate.isInterfaceType(peripheral.getType(e[2])) then gate = Gate.find() end
                if not relay then
                    relay, why = GDO.newRelay(function() return gate end)
                    if relay then log("Radio connected", colors.lime) end
                end
                redraw = true
            elseif name == "peripheral_detach" then
                if gate and e[2] == gate.name then gate = nil end
                if relay and relay:detached(e[2]) then relay, why = nil, "No wireless or ender modem" end
                redraw = true
            elseif name == "term_resize" then
                redraw = true
            end
            if redraw then draw() end
        end
    end

    parallel.waitForAny(listener, worker)
    if relay then relay:close() end
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
    print("GDO relay stopped.")
end

---------------------------------------------------------------------------
-- gdo send <code>
---------------------------------------------------------------------------

local function runSend(code)
    code = IDC.clean(code)
    if not code then
        printError("A code is 1 to 16 letters, digits or dashes: gdo send <code>")
        return
    end
    local radio = GDO.findRadio()
    if not radio then
        printError("The GDO needs a wireless or ender modem.")
        return
    end
    local client = Client.new(radio)
    local found = {}
    client:ping()
    local timer = os.startTimer(CONFIG.listenTime)
    while true do
        local e = table.pack(os.pullEvent())
        if e[1] == "timer" and e[2] == timer then break end
        local msg, distance = client:read(e)
        if msg and msg.type == "status" then
            msg.distance = distance
            found[msg.relay] = msg
        end
    end
    local link = bestRelay(found)
    if not link then
        client:close()
        printError("No gate in range. Its computer needs a wireless or ender modem and the Gate Room or gdo relay.")
        return
    end
    print(string.format("%s, %dm: %s", link.label, math.floor(link.distance + 0.5), stateText(link)))
    if not link.connected then client:close() return end
    if not link.canSend then
        client:close()
        printError(link.why or "That gate can't send codes")
        return
    end
    local seq = client:sendCode(link.relay, code)
    timer = os.startTimer(CONFIG.replyTime)
    local sent = false
    while true do
        local e = table.pack(os.pullEvent())
        if e[1] == "timer" and e[2] == timer then
            print(sent and "No answer from the other side." or "The gate's computer did not answer.")
            break
        end
        local msg = client:read(e)
        if msg then
            if msg.type == "sent" and msg.seq == seq then
                sent = true
                remember(code)
                print("Code " .. code .. " sent. Waiting for the other side...")
                timer = os.startTimer(CONFIG.answerTime)
            elseif msg.type == "failed" and (msg.seq == nil or msg.seq == seq) then
                printError("Not sent: " .. tostring(msg.why))
                break
            elseif msg.type == "answer" and sent then
                if msg.result == "accepted" then
                    print("Code accepted" .. (msg.name and (" as " .. msg.name) or "") .. ". The way is open.")
                else
                    printError("Code rejected. Their iris stays closed.")
                end
                break
            end
        end
    end
    client:close()
end

---------------------------------------------------------------------------
-- the GDO screen
---------------------------------------------------------------------------

-- 3x5 LCD digits and letters, rows top to bottom
local FONT = {
    ["0"] = { "###", "#.#", "#.#", "#.#", "###" }, ["1"] = { ".#.", "##.", ".#.", ".#.", "###" },
    ["2"] = { "###", "..#", "###", "#..", "###" }, ["3"] = { "###", "..#", "###", "..#", "###" },
    ["4"] = { "#.#", "#.#", "###", "..#", "..#" }, ["5"] = { "###", "#..", "###", "..#", "###" },
    ["6"] = { "###", "#..", "###", "#.#", "###" }, ["7"] = { "###", "..#", "..#", "..#", "..#" },
    ["8"] = { "###", "#.#", "###", "#.#", "###" }, ["9"] = { "###", "#.#", "###", "..#", "###" },
    ["-"] = { "...", "...", "###", "...", "..." },
    A = { ".#.", "#.#", "###", "#.#", "#.#" }, B = { "##.", "#.#", "##.", "#.#", "##." },
    C = { ".##", "#..", "#..", "#..", ".##" }, D = { "##.", "#.#", "#.#", "#.#", "##." },
    E = { "###", "#..", "##.", "#..", "###" }, F = { "###", "#..", "##.", "#..", "#.." },
    G = { ".##", "#..", "#.#", "#.#", ".##" }, H = { "#.#", "#.#", "###", "#.#", "#.#" },
    I = { "###", ".#.", ".#.", ".#.", "###" }, J = { "..#", "..#", "..#", "#.#", ".#." },
    K = { "#.#", "#.#", "##.", "#.#", "#.#" }, L = { "#..", "#..", "#..", "#..", "###" },
    M = { "#.#", "###", "###", "#.#", "#.#" }, N = { "##.", "#.#", "#.#", "#.#", "#.#" },
    O = { ".#.", "#.#", "#.#", "#.#", ".#." }, P = { "##.", "#.#", "##.", "#..", "#.." },
    Q = { ".#.", "#.#", "#.#", "##.", ".##" }, R = { "##.", "#.#", "##.", "#.#", "#.#" },
    S = { ".##", "#..", ".#.", "..#", "##." }, T = { "###", ".#.", ".#.", ".#.", ".#." },
    U = { "#.#", "#.#", "#.#", "#.#", "###" }, V = { "#.#", "#.#", "#.#", "#.#", ".#." },
    W = { "#.#", "#.#", "###", "###", "#.#" }, X = { "#.#", "#.#", ".#.", "#.#", "#.#" },
    Y = { "#.#", "#.#", ".#.", ".#.", ".#." }, Z = { "###", "..#", ".#.", "#..", "###" },
}

-- colours of the device; the LCD's are mixed into palette slots the GDO doesn't otherwise use
local BODY, EDGE, KEY, KEY_TEXT = colors.orange, colors.brown, colors.lightGray, colors.black
local LCD, GHOST, INK = colors.lightBlue, colors.cyan, colors.black
local SEND_KEY, LIP, STRIP = colors.green, colors.brown, colors.black
local PALETTE = {
    [colors.lightBlue] = 0xA3B591, -- LCD glass
    [colors.cyan] = 0x93A582,      -- unlit LCD segments
    [colors.brown] = 0x6B4A2B,     -- dark casing
    [colors.orange] = 0xD9822B,    -- casing
    [colors.green] = 0x4E8A3A,     -- SEND key
}

local function runDevice()
    if not term.isColor() then
        printError("The GDO needs an advanced pocket computer (or an advanced computer).")
        return
    end
    local native = term.current()
    local radio = GDO.findRadio()
    local client = radio and Client.new(radio)
    local speaker = CONFIG.sounds and peripheral.find("speaker")

    local entry = ""                 -- the code being typed
    local memory = remembered()      -- the last code sent
    local link = nil                 -- the gate's status, with distance and when it was heard
    local found, collecting = {}, nil
    local phase, detail = "idle", nil -- idle, sending, waiting, accepted, rejected, failed, noanswer
    local seq, sentCode = nil, nil
    local pingTimer, collectTimer, phaseTimer
    local pressed, pressedTimer = nil, nil
    local blink, blinkTimer = true, nil
    local running = true

    for c, rgb in pairs(PALETTE) do native.setPaletteColor(c, rgb) end

    local function tone(kind)
        if not speaker then return end
        if kind == "key" then pcall(speaker.playNote, "hat", 0.6, 20)
        elseif kind == "send" then pcall(speaker.playNote, "bit", 1, 18)
        elseif kind == "accepted" then
            pcall(speaker.playNote, "bell", 1, 12)
            pcall(speaker.playNote, "bell", 1, 19)
        elseif kind == "rejected" then pcall(speaker.playNote, "didgeridoo", 1, 2)
        end
    end

    -- layout: 26x20 on a pocket computer; centred on bigger screens
    local W, H = term.getSize()
    local L = {}
    local function layout()
        W, H = term.getSize()
        L.w = math.min(26, W)
        L.x = math.floor((W - L.w) / 2) + 1
        L.gap = H >= 20 and 1 or 0 -- a pocket computer has room for a gap under the keypad
        L.title = 1
        L.lcdTop = 2       -- top text line of the LCD
        L.digits = 3       -- 5 rows of big digits
        L.lcdBottom = 8
        L.keys = 10        -- 4 rows of keys, one row apart
        L.status = 17 + L.gap
        L.footer = L.status + 2
        L.keyW = math.floor((L.w - 8) / 3)
        L.keyX = {}
        local x = L.x + math.floor((L.w - (3 * L.keyW + 4)) / 2)
        for i = 1, 3 do L.keyX[i] = x + (i - 1) * (L.keyW + 2) end
    end
    layout()

    local KEYS = {
        { "1", "2", "3" }, { "4", "5", "6" }, { "7", "8", "9" }, { "CLR", "0", "SEND" },
    }

    local function fill(x, y, w, bg)
        if w <= 0 then return end
        term.setCursorPos(x, y)
        term.setBackgroundColor(bg)
        term.write(string.rep(" ", w))
    end

    local function text(x, y, s, fg, bg)
        term.setCursorPos(x, y)
        term.setTextColor(fg)
        term.setBackgroundColor(bg)
        term.write(s)
    end

    local function centre(y, s, fg, bg, x0, w)
        x0, w = x0 or L.x, w or L.w
        s = s:sub(1, w)
        text(x0 + math.floor((w - #s) / 2), y, s, fg, bg)
    end

    local function shown()
        if entry ~= "" then return entry end
        return memory or ""
    end

    local function lcdTopText()
        if phase == "sending" then return "TRANSMIT", true end
        if phase == "waiting" then return "AWAIT REPLY", true end
        if phase == "accepted" then return "IRIS OPEN", true end
        if phase == "rejected" then return "REJECTED", true end
        if phase == "failed" then return "NOT SENT", false end
        if phase == "noanswer" then return "NO REPLY", false end
        if entry ~= "" then return "ENTER CODE", false end
        if not client then return "NO RADIO", false end
        if not link then return "SEARCHING", false end
        return memory and "MEM" or "ENTER CODE", false
    end

    local function lcdBottomText()
        if not client then return "FIT A MODEM" end
        if not link then return "NO GATE" end
        local d = math.floor(link.distance + 0.5)
        local s = link.connected and (link.outgoing and "OPEN" or "IN") or (link.state == "OFFLINE" and "OFF" or "IDLE")
        local name = link.label:upper()
        -- "NAME 12M OPEN" inside the glass, which is L.w - 4 wide
        local room = L.w - 7 - #s - #tostring(d)
        if #name > room then name = name:sub(1, math.max(0, room)) end
        return name .. " " .. d .. "M " .. s
    end

    local function drawDigits(code)
        local y0 = L.digits
        local inner = L.w - 2
        -- big digits for up to 6 characters, small text for longer codes
        local big = #code <= math.floor((inner + 1) / 4)
        for row = 0, 4 do fill(L.x + 1, y0 + row, inner, LCD) end
        if code == "" then
            centre(y0 + 2, "- - -", GHOST, LCD, L.x + 1, inner)
            return
        end
        if not big then
            centre(y0 + 2, code, INK, LCD, L.x + 1, inner)
            return
        end
        local width = #code * 4 - 1
        local x0 = L.x + 1 + math.floor((inner - width) / 2)
        for i = 1, #code do
            local glyph = FONT[code:sub(i, i)] or FONT["-"]
            for row = 1, 5 do
                local bits = glyph[row]
                for col = 1, 3 do
                    term.setCursorPos(x0 + (i - 1) * 4 + col - 1, y0 + row - 1)
                    term.setBackgroundColor(bits:sub(col, col) == "#" and INK or GHOST)
                    term.write(" ")
                end
            end
        end
    end

    local function signalBars()
        -- three bars rising left to right, lit by how close the gate is
        local lit = 0
        if link then
            if link.distance < 16 then lit = 3 elseif link.distance < 40 then lit = 2 else lit = 1 end
        end
        local chars = { "\144", "\148", "\149" }
        for i = 1, 3 do
            text(L.x + L.w - 5 + i, L.title, chars[i], i <= lit and colors.lime or colors.gray, EDGE)
        end
    end

    local function wrap(s, width)
        local lines, line = {}, ""
        for word in s:gmatch("%S+") do
            if line == "" then line = word
            elseif #line + 1 + #word <= width then line = line .. " " .. word
            else lines[#lines + 1] = line line = word end
        end
        if line ~= "" then lines[#lines + 1] = line end
        return lines
    end

    -- two lines on a dark strip under the keypad; a message too long for them is wrapped over both
    local function statusLines()
        local a, b, ca, cb = "", "", colors.white, colors.lightGray
        if not client then
            a, b = "No radio.", "Fit a wireless or ender modem."
        elseif phase == "sending" then
            a, b = "Transmitting " .. sentCode, "to " .. (link and link.label or "the gate")
        elseif phase == "waiting" then
            a, b = "Code " .. sentCode .. " went through.", "Waiting for their answer"
        elseif phase == "accepted" then
            a, b = "Code accepted" .. (detail and (": " .. detail) or "."), "Their iris is open. Go!"
            ca, cb = colors.lime, colors.lime
        elseif phase == "rejected" then
            a, b = "Code rejected.", "Their iris stays closed."
            ca, cb = colors.red, colors.red
        elseif phase == "failed" then
            a, b = "Not sent:", tostring(detail or "")
            cb = colors.orange
        elseif phase == "noanswer" then
            a, b = "No answer.", tostring(detail or "")
        elseif not link then
            a, b = "No gate in range.", "Stand by a gate's computer."
        else
            a = link.label .. ", " .. math.floor(link.distance + 0.5) .. "m"
            b = stateText(link)
            if link.connected and not link.canSend then b, cb = link.why or "It can't send codes", colors.orange end
            if link.connected and link.canSend then cb = colors.white end
        end
        local width = L.w - 2
        if #a > width or #b > width then
            local lines = wrap(a .. " " .. b, width)
            a, b = lines[1] or "", lines[2] or ""
            if lines[3] then b = b:sub(1, width - 2) .. ".." end
            if cb ~= colors.lightGray then ca = cb end
            cb = ca
        end
        fill(L.x, L.status, L.w, STRIP)
        fill(L.x, L.status + 1, L.w, STRIP)
        text(L.x + 1, L.status, a:sub(1, width), ca, STRIP)
        text(L.x + 1, L.status + 1, b:sub(1, width), cb, STRIP)
    end

    local function draw()
        term.setBackgroundColor(colors.black)
        term.clear()
        for y = 1, math.min(H, L.footer) do fill(L.x, y, L.w, BODY) end
        -- title strip
        fill(L.x, L.title, L.w, EDGE)
        text(L.x + 1, L.title, "GDO", colors.white, EDGE)
        text(L.x + 5, L.title, "IDC", colors.orange, EDGE)
        signalBars()
        -- LCD
        for y = L.lcdTop, L.lcdBottom do fill(L.x + 1, y, L.w - 2, LCD) end
        local top, flashing = lcdTopText()
        if not (flashing and not blink) then
            text(L.x + 2, L.lcdTop, top, INK, LCD)
        end
        local code = shown()
        if #code > 0 and #code <= 16 then
            local count = tostring(#code) .. "/16"
            if entry == "" then count = "" end
            text(L.x + L.w - 2 - #count, L.lcdTop, count, INK, LCD)
        end
        drawDigits(code)
        local bottom = lcdBottomText()
        text(L.x + 2, L.lcdBottom, bottom:sub(1, L.w - 4), INK, LCD)
        -- keypad
        for r, row in ipairs(KEYS) do
            local y = L.keys + (r - 1) * 2
            for c, label in ipairs(row) do
                local x = L.keyX[c]
                local face = label == "SEND" and SEND_KEY or KEY
                local ink = label == "SEND" and colors.white or KEY_TEXT
                if pressed == label then face, ink = colors.white, colors.black end
                fill(x, y, L.keyW, face)
                centre(y, label, ink, face, x, L.keyW)
                if y + 1 <= H then
                    text(x, y + 1, string.rep("\131", L.keyW), LIP, BODY)
                end
            end
        end
        statusLines()
        -- footer
        if L.footer <= H then
            fill(L.x, L.footer, L.w, EDGE)
            centre(L.footer, "Enter send  Ctrl+T off", colors.lightGray, EDGE)
        end
    end

    local function setPhase(p, d, seconds)
        phase, detail = p, d
        if phaseTimer then os.cancelTimer(phaseTimer) end
        phaseTimer = seconds and os.startTimer(seconds) or nil
        if p == "sending" or p == "waiting" or p == "accepted" or p == "rejected" then
            if not blinkTimer then blinkTimer = os.startTimer(0.5) end
        end
    end

    local function ping()
        if not client then return end
        found = {}
        collecting = true
        client:ping()
        collectTimer = os.startTimer(CONFIG.listenTime)
    end

    local function send()
        local code = IDC.clean(shown())
        if not code then
            setPhase("failed", "Enter a code first", 4)
            return
        end
        if not client then
            setPhase("failed", "Fit a wireless or ender modem", 4)
            return
        end
        if not link then
            setPhase("failed", "No gate in range", 4)
            return
        end
        if not link.connected then
            setPhase("failed", "No wormhole at " .. link.label, 4)
            return
        end
        if not link.canSend then
            setPhase("failed", link.why or "That gate can't send codes", 6)
            return
        end
        tone("send")
        sentCode = code
        seq = client:sendCode(link.relay, code)
        setPhase("sending", nil, CONFIG.replyTime)
    end

    local function press(label)
        pressed = label
        if pressedTimer then os.cancelTimer(pressedTimer) end
        pressedTimer = os.startTimer(0.15)
        tone("key")
        if label == "CLR" then
            entry = ""
            if phase ~= "sending" and phase ~= "waiting" then setPhase("idle") end
        elseif label == "SEND" then
            if phase ~= "sending" and phase ~= "waiting" then send() end
        else
            if phase ~= "sending" and phase ~= "waiting" then
                if phase ~= "idle" then setPhase("idle") end
                if #entry < 16 then entry = entry .. label end
            end
        end
    end

    local function keyAt(x, y)
        for r, row in ipairs(KEYS) do
            local ky = L.keys + (r - 1) * 2
            if y == ky or y == ky + 1 then
                for c, label in ipairs(row) do
                    if x >= L.keyX[c] and x < L.keyX[c] + L.keyW then return label end
                end
            end
        end
        return nil
    end

    local function onRadio(msg, distance)
        if msg.type == "status" then
            msg.distance = distance
            if collecting then found[msg.relay] = msg end
            if link and msg.relay == link.relay and distance then
                msg.heardAt = os.clock()
                link = msg
            end
        elseif msg.type == "sent" and phase == "sending" and msg.seq == seq then
            memory, entry = sentCode, ""
            remember(sentCode)
            setPhase("waiting", nil, CONFIG.answerTime)
        elseif msg.type == "failed" and (phase == "sending" or phase == "waiting") and (msg.seq == nil or msg.seq == seq) then
            setPhase("failed", msg.why, 6)
            tone("rejected")
        elseif msg.type == "answer" and phase == "waiting" then
            if msg.result == "accepted" then
                setPhase("accepted", msg.name, 10)
                tone("accepted")
            else
                setPhase("rejected", nil, 10)
                tone("rejected")
            end
        end
    end

    ping()
    pingTimer = os.startTimer(CONFIG.pingEvery)
    draw()
    while running do
        local e = table.pack(os.pullEventRaw())
        local name = e[1]
        if name == "terminate" then
            running = false
        elseif name == "timer" then
            local id = e[2]
            if id == collectTimer then
                collecting = false
                local best = bestRelay(found)
                if best then
                    best.heardAt = os.clock()
                    link = best
                elseif link and os.clock() - (link.heardAt or 0) > CONFIG.pingEvery * 2 + 1 then
                    link = nil
                end
            elseif id == pingTimer then
                pingTimer = os.startTimer(CONFIG.pingEvery)
                -- keep talking to the same gate while a code is out
                if phase ~= "sending" and phase ~= "waiting" then ping() end
            elseif id == phaseTimer then
                phaseTimer = nil
                if phase == "sending" then
                    setPhase("noanswer", "The gate's computer did not answer", 6)
                elseif phase == "waiting" then
                    setPhase("noanswer", "Nobody there trusts codes", 8)
                else
                    setPhase("idle")
                end
            elseif id == pressedTimer then
                pressed, pressedTimer = nil, nil
            elseif id == blinkTimer then
                blink = not blink
                if phase == "sending" or phase == "waiting" or phase == "accepted" or phase == "rejected" then
                    blinkTimer = os.startTimer(0.5)
                else
                    blinkTimer, blink = nil, true
                end
            end
        elseif name == "modem_message" and client then
            local msg, distance = client:read(e)
            if msg then onRadio(msg, distance) end
        elseif name == "mouse_click" then
            local k = keyAt(e[3], e[4])
            if k then press(k) end
        elseif name == "char" then
            local c = e[2]:upper()
            if c:match("^[%w%-]$") then
                if phase ~= "sending" and phase ~= "waiting" then
                    if phase ~= "idle" then setPhase("idle") end
                    if #entry < 16 then entry = entry .. c end
                    tone("key")
                end
            end
        elseif name == "key" then
            local k = e[2]
            if k == keys.enter or k == keys.numPadEnter then press("SEND")
            elseif k == keys.backspace then entry = entry:sub(1, -2)
            elseif k == keys.delete then press("CLR")
            end
        elseif name == "peripheral" then
            if not client then
                radio = GDO.findRadio()
                if radio then
                    client = Client.new(radio)
                    ping()
                end
            end
            if not speaker and CONFIG.sounds then speaker = peripheral.find("speaker") end
        elseif name == "peripheral_detach" then
            if client and e[2] == client.radioName then
                client, link = nil, nil
                if phase == "sending" or phase == "waiting" then setPhase("failed", "The radio was removed", 6) end
            end
        elseif name == "term_resize" then
            layout()
        end
        if running then draw() end
    end

    if client then client:close() end
    for c in pairs(PALETTE) do native.setPaletteColor(c, term.nativePaletteColor(c)) end
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)
    print("GDO off.")
end

---------------------------------------------------------------------------

local cmd = args[1] and args[1]:lower()
if cmd == "relay" then
    runRelay()
elseif cmd == "send" then
    runSend(args[2])
elseif cmd == nil then
    runDevice()
else
    print("Usage:")
    print("  gdo               the GDO (pocket computer)")
    print("  gdo send <code>   send a code and print the answer")
    print("  gdo relay         relay codes at a gate's computer")
end
