--
--   Gate Room
--   An SGC style gate room screen for an advanced monitor (CC: Tweaked)
--
--   Shows the gate the computer is connected to, drawn in the look of its
--   series (SG-1, Movie, Atlantis, Universe, Tollan, Classic, Infinity, Legacy
--   Hybrid, SGCraft): chevrons lock one by one, the inner ring turns, the
--   wormhole forms with a kawoosh and the iris closes over it.
--
--   Works with Stargate Journey (basic, crystal and advanced crystal interface),
--   SGCraft (Greg's and SGCraft 2.x), Lantea: Stargates (0.7.7.0+, Milky Way
--   gates dial) and Just Stargate Mod (1.20.1).
--
--   Usage:
--     gateroom              draw on the first advanced monitor (or this screen if there is none)
--     gateroom <monitor>    draw on that monitor, e.g. gateroom monitor_3
--     gateroom term         draw on the computer screen
--

local VERSION = "1.0"

--
-- CONFIGURATION
--
local CONFIG = {
    -- address book shared with the Personal Dialer and the Network Hub
    dataFile = "dialer_addresses.db",
    -- peripheral name of the gate interface, nil = first one found
    interfaceName = nil,
    -- text scale of the monitor (0.5 gives the most detail)
    textScale = 0.5,

    -- seconds between animation frames, raise it if the server is slow
    frameTime = 0.15,
    -- seconds between gate status checks when nothing is moving
    pollInterval = 1,

    -- dialing speed
    symbolDelay = 0.5,
    chevronDelay = 0.4,
    stepTimeout = 60,
    connectTimeout = 10,
    -- engage symbols directly instead of turning the Milky Way ring
    fastDial = false,

    -- close the iris when another gate dials in (SGC protocol). Your own team
    -- coming home will hit the iris too, so it is off by default.
    autoIris = false,
    -- redstone side to power while an incoming wormhole is forming, e.g. "back"
    alarmSide = nil,
    -- play an alarm on an attached speaker for incoming wormholes
    klaxon = true,
    -- close an outgoing wormhole this many seconds after someone steps through, 0 = never
    autoClose = 0,
}
--
-- END OF CONFIGURATION
--

local A = require("sgc.address")
local Book = require("sgc.book")
local Gate = require("sgc.gate")
local Styles = require("sgc.styles")
local Pixels = require("sgc.pixels")
local Ring = require("sgc.ring")
local UI = require("sgc.ui")

local args = { ... }
local fit, pad = UI.fit, UI.pad

---------------------------------------------------------------------------
-- Screen
---------------------------------------------------------------------------

local native = term.current()
local monitor, monitorName
if args[1] ~= "term" then
    if args[1] then
        monitor = peripheral.wrap(args[1])
        if not monitor or peripheral.getType(args[1]) ~= "monitor" then error("No monitor called " .. args[1], 0) end
    else
        monitor = peripheral.find("monitor", function(_, m) return m.isColor() end)
    end
    if monitor then
        if not monitor.isColor() then error("The gate room needs an advanced monitor", 0) end
        monitorName = peripheral.getName(monitor)
        monitor.setTextScale(CONFIG.textScale)
    end
end
local target = monitor or native
local ui = UI.new(target)
local W, H

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local book = Book.open(CONFIG.dataFile)
local gate = Gate.find(CONFIG.interfaceName)
local style
local canvas, ring, L
local overlay = nil -- { page = 1 } while the destination list is shown
local dial = { active = false, abort = false, entry = nil, address = nil, endedAt = -10, failed = false }
local message = { text = "", color = colors.lightGray }
local manual = ""
local rotating, rotation, lastRotationRead = false, 0, 0
local running = true
local speaker = peripheral.find("speaker")
local alarm = { on = false, lastBeep = 0, beep = 0 }
local autoCloseTimer
local lastFrame = os.clock()

local function setMessage(text, color)
    message.text = text or ""
    message.color = color or colors.lightGray
end

-- black, or a starfield for styles drawn in space
local function paintBackground()
    canvas:clear(colors.black)
    if style.stars then
        for y = 1, canvas.h do
            for x = 1, canvas.w do
                local star = Ring.starAt(x, y)
                if star then canvas:set(x, y, star) end
            end
        end
    end
    canvas:invalidate()
end

local function chooseStyle()
    style = Styles.resolve(book:setting("gateroomStyle", "auto"), gate)
    Styles.apply(target, style)
    if canvas then paintBackground() end
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

local function layout()
    W, H = target.getSize()
    L = { w = W, h = H }
    if W >= 44 then
        L.pw = math.max(22, math.min(36, math.floor(W * 0.42)))
        if W - L.pw < 20 then L.pw = W - 20 end
    else
        L.pw = 0
    end
    L.px = W - L.pw + 1
    L.gx, L.gy = 1, 2
    L.gw = W - L.pw
    L.gh = H - 1
    if L.pw == 0 then L.gh = H - 2 end
    canvas = Pixels.new(L.gw, L.gh, colors.black)
    local r = math.min(canvas.w, canvas.h) / 2 / 1.1
    ring = Ring.new(canvas, canvas.w / 2, canvas.h / 2 + 0.5, r)
    paintBackground()
    target.setBackgroundColor(colors.black)
    target.clear()
end

---------------------------------------------------------------------------
-- Gate helpers
---------------------------------------------------------------------------

-- symbols to show, chevrons in the address, chevrons locked
local function chevronPlan()
    if not gate then return {}, 7, 0 end
    local origin = gate.originSymbol
    local syms
    if dial.active and dial.address then
        syms = A.symbols(dial.address)
    elseif gate.remote and gate.state ~= "IDLE" then
        syms = A.symbols(gate.remote)
    end
    local lit = gate.connected and 99 or gate.chevrons
    if syms then
        if origin ~= nil then syms[#syms + 1] = origin end
        return syms, #syms, math.min(lit, #syms)
    end
    syms = {}
    for i, s in ipairs(gate.engaged) do syms[i] = s end
    local total = math.max(7, #syms)
    local last = syms[#syms]
    local lastIsOrigin = last == 0 or (type(last) == "string" and A.isOriginName(last))
    if origin ~= nil and #syms >= 7 and not lastIsOrigin and not gate.connected then total = #syms + 1 end
    return syms, total, math.min(lit, total)
end

local function animating()
    if overlay then return false end
    if not gate then return alarm.on end
    if gate.state ~= "IDLE" and gate.state ~= "OFFLINE" then return true end
    if gate.iris and gate.iris > 0 and gate.iris < 100 then return true end
    if gate.closingAt and os.clock() - gate.closingAt < 1 then return true end
    return rotating or dial.active
end

local function updateRotation(t)
    if not gate then return end
    local moving = gate.state == "DIALING" or gate.state == "INCOMING" and not gate.connected
    if gate.mod == "sgcraft" then
        -- SGCraft doesn't report the ring position: turn it while the gate dials
        if moving then rotation = (rotation + (t - lastFrame) * 70) % 360 end
        return
    end
    if (rotating or dial.active or moving) and t - lastRotationRead > 0.05 then
        lastRotationRead = t
        rotation = gate:rotation() or rotation
    end
end

local function startDial(entry, address)
    address = address or (entry and entry.address)
    if not gate then setMessage("No stargate interface connected", colors.red) return end
    if not address then setMessage((entry and entry.name or "This entry") .. " has no address yet", colors.orange) return end
    if dial.active then setMessage("Already dialing - CLOSE aborts", colors.orange) return end
    gate:poll()
    if gate.state ~= "IDLE" then setMessage("The gate is busy", colors.red) return end
    local dialable, why = A.dialableBy(address, gate.mod)
    if not dialable then
        setMessage(why, colors.red)
        return
    end
    dial.active, dial.abort, dial.entry, dial.address = true, false, entry, address
    gate.remote, gate.outgoing = address, true
    setMessage("Dialing " .. (entry and entry.name or A.format(address)), colors.lightGray)
    os.queueEvent("gateroom_dial")
end

local function closeGate()
    if dial.active then
        dial.abort = true
        setMessage("Aborting dial...", colors.orange)
        return
    end
    if not gate then return end
    gate:poll()
    if gate.state == "IDLE" then setMessage("The gate is already idle", colors.gray) return end
    if autoCloseTimer then os.cancelTimer(autoCloseTimer) autoCloseTimer = nil end
    gate:close()
    setMessage(gate.state == "INCOMING" and "Trying to close the incoming wormhole" or "Closing the gate", colors.lightGray)
end

local function toggleIris()
    if not gate then return end
    if not gate.hasIris then setMessage("No iris installed on this gate", colors.orange) return end
    local closing = not (gate.iris and gate.iris > 0)
    local ok, err = gate:toggleIris()
    if ok == false then setMessage("Iris: " .. tostring(err), colors.red)
    else setMessage(closing and "Closing the iris" or "Opening the iris", colors.lightGray) end
end

local function cycleStyle()
    book:set("gateroomStyle", Styles.nextSetting(book:setting("gateroomStyle", "auto")))
    chooseStyle()
    local s = book:setting("gateroomStyle", "auto")
    setMessage("Style: " .. (s == "auto" and ("Auto (" .. style.name .. ")") or style.name), colors.lightGray)
end

local function quit()
    if dial.active then dial.abort = true end
    running = false
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function drawHeader(t)
    local flash = alarm.on and math.floor(t * 2) % 2 == 0
    local bg = flash and colors.red or colors.gray
    ui:fill(1, 1, W, 1, bg)
    local title = " " .. (style.room or "GATE ROOM")
    ui:write(1, 1, fit(title, W), colors.white, bg)
    local right
    if gate then
        right = gate.localAddress and A.format(gate.localAddress) or (style.name .. " gate")
    else
        right = "no interface"
    end
    if #title + #right + 3 <= W then
        ui:write(W - #right, 1, right, flash and colors.white or colors.orange, bg)
    end
end

local STATUS = {
    IDLE = { "GATE IDLE", colors.white, colors.gray },
    OFFLINE = { "NO STARGATE", colors.white, colors.gray },
    CLOSING = { "WORMHOLE CLOSING", colors.black, colors.lightBlue },
}

local function statusLine(t, total, lit)
    if not gate then return "NO STARGATE", colors.white, colors.gray end
    if gate.fault then return "GATE FAULT", colors.white, colors.red end
    local st = gate.state
    local flash = math.floor(t * 2) % 2 == 0
    if st == "INCOMING" then
        if gate.connected then return "INCOMING WORMHOLE", colors.white, colors.red end
        return "OFFWORLD ACTIVATION", flash and colors.white or colors.red, flash and colors.red or colors.black
    elseif st == "DIALING" then
        if lit <= 0 then return "DIALING", colors.black, colors.orange end
        return "CHEVRON " .. lit .. (lit >= total and " LOCKED" or " ENCODED"), colors.black, colors.orange
    elseif st == "OPEN" then
        local age = gate:openSeconds() or 99
        if age < 1.6 then return "KAWOOSH", colors.black, colors.white end
        return "WORMHOLE ESTABLISHED", colors.black, colors.lightBlue
    end
    local s = STATUS[st] or STATUS.IDLE
    return s[1], s[2], s[3]
end

local function symbolText(s)
    if s == 0 or (type(s) == "string" and A.isOriginName(s)) then return "PoO" end
    return tostring(s)
end

local function drawPanel(t)
    if L.pw == 0 then
        -- narrow screen: one status line under the gate
        local syms, total, lit = chevronPlan()
        local text, fg, bg = statusLine(t, total, lit)
        ui:fill(1, H, W, 1, bg)
        ui:center(1, H, W, text, fg, bg)
        return
    end
    local x, w = L.px, L.pw
    local y = 2
    local bg = colors.black
    local function line(s, fg, b)
        ui:write(x, y, pad(" " .. s, w), fg or colors.white, b or bg)
        y = y + 1
    end
    local syms, total, lit = chevronPlan()
    local tall = H >= 30
    -- JSG symbols are names: give them a wider column
    local names = false
    for _, s in ipairs(syms) do if type(s) == "string" and #s > 1 then names = true end end
    local symW = names and math.max(4, math.min(14, w - 19)) or 4

    line("DIALING COMPUTER", colors.orange)
    if gate then
        local kind = gate.typeName .. (gate.generation and ("  gen " .. gate.generation) or "")
        line(fit(style.name .. " style - " .. kind, w - 1), colors.lightGray)
    else
        line("no interface found", colors.red)
    end
    ui:fill(x, y, w, 1, bg) ui:write(x + 1, y, string.rep("\140", w - 2), colors.gray, bg) y = y + 1

    -- chevrons
    if tall then
        local rows = math.max(7, total)
        for i = 1, rows do
            local s = syms[i]
            local on = i <= lit and i <= total
            local status = ""
            local sc = colors.gray
            if on then
                status, sc = (i == total) and "LOCKED" or "ENCODED", colors.orange
            elseif dial.active and i == lit + 1 and i <= total then
                status, sc = (math.floor(t * 3) % 2 == 0) and "ENGAGING" or "", colors.lightGray
            end
            local num = string.format("%d", i)
            local chev = on and colors.orange or colors.gray
            ui:write(x, y, pad("", w), colors.white, bg)
            ui:write(x + 1, y, num, colors.lightGray, bg)
            ui:write(x + 3, y, "\31", i <= total and chev or colors.black, bg)
            if s ~= nil and i <= total then ui:write(x + 5, y, fit(symbolText(s), symW), on and colors.white or colors.lightGray, bg) end
            ui:write(x + 6 + symW, y, fit(status, w - 7 - symW), sc, bg)
            y = y + 1
        end
    else
        -- compact: one or two lines of chevrons
        local parts = {}
        for i = 1, total do
            local s = syms[i]
            local text = s ~= nil and symbolText(s) or ""
            if names then text = text:sub(1, 3) end
            parts[#parts + 1] = { "\31" .. text, i <= lit and colors.orange or colors.gray }
        end
        for row = 1, 2 do
            ui:fill(x, y, w, 1, bg)
            local cx = x + 1
            while #parts > 0 and cx + #parts[1][1] <= x + w - 1 do
                local p = table.remove(parts, 1)
                ui:write(cx, y, p[1], p[2], bg)
                cx = cx + #p[1] + 1
            end
            y = y + 1
        end
    end
    ui:fill(x, y, w, 1, bg) ui:write(x + 1, y, string.rep("\140", w - 2), colors.gray, bg) y = y + 1

    -- status box
    local text, fg, sbg = statusLine(t, total, lit)
    ui:fill(x + 1, y, w - 2, tall and 3 or 1, sbg)
    ui:center(x + 1, y + (tall and 1 or 0), w - 2, text, fg, sbg)
    ui:fill(x, y, 1, tall and 3 or 1, bg) ui:fill(x + w - 1, y, 1, tall and 3 or 1, bg)
    y = y + (tall and 4 or 2)
    ui:fill(x, y - 1, w, 1, bg)

    -- details
    if gate then
        local who
        if gate.state ~= "IDLE" then
            local addr = (dial.active and dial.address) or gate.remote
            local name = dial.active and dial.entry and dial.entry.name or (addr and book:describe(addr))
            if name then who = (gate.outgoing and "To   " or "From ") .. name end
        end
        line(who or "", colors.white)
        local open = gate.connected and gate:openSeconds()
        local timer = ""
        if open and gate.state ~= "CLOSING" then
            timer = "Open " .. UI.duration(open)
            if autoCloseTimer then timer = timer .. "  closing soon" end
        end
        line(timer, colors.lightBlue)
        local energy = "Energy " .. (gate.energy and (UI.energy(gate.energy) .. " " .. (gate.energyUnit or "FE")) or "?")
        if gate.zpmCount and gate.zpmCount > 0 then energy = energy .. "  ZPM x" .. gate.zpmCount end
        line(energy, colors.lightGray)
        local iris = "none"
        local ic = colors.gray
        if gate.hasIris then
            local p = gate.iris or 0
            if p >= 100 then iris, ic = "CLOSED", colors.red
            elseif p <= 0 then iris, ic = "OPEN", colors.lime
            else iris, ic = "MOVING " .. math.floor(p) .. "%", colors.orange end
        end
        ui:write(x, y, pad(" Iris", w), colors.lightGray, bg)
        ui:write(x + 8, y, iris, ic, bg)
        y = y + 1
    end

    -- buttons at the bottom
    local by = H - (tall and 4 or 1)
    local bw = math.floor((w - 3) / 2)
    local b1, b2 = x + 1, x + 2 + bw
    -- message above the buttons
    local msgLines = UI.wrap(message.text, w - 2)
    local my = y
    while my < by - 1 do
        local l = msgLines[my - y + 1] or ""
        if my - y + 1 > 2 then l = "" end
        ui:write(x, my, pad(" " .. l, w), message.color, bg)
        my = my + 1
    end
    if manual ~= "" then ui:write(x, by - 1, pad(" > " .. manual .. "_", w), colors.orange, bg)
    else ui:write(x, by - 1, pad("", w), colors.white, bg) end

    if tall then
        ui:fill(x, by, w, 5, bg)
        ui:bigButton(b1, by, bw, "DIAL", colors.black, colors.orange, function() overlay = { page = 1 } book:reload() end)
        ui:bigButton(b2, by, bw, dial.active and "ABORT" or "CLOSE", colors.white, colors.red, closeGate)
        ui:bigButton(b1, by + 3, bw, "IRIS", colors.black, gate and gate.hasIris and colors.lightGray or colors.gray, toggleIris)
        ui:bigButton(b2, by + 3, bw, "STYLE", colors.black, colors.lightGray, cycleStyle)
    else
        -- short screens: two rows of buttons on the last two lines
        ui:fill(x, by, w, 2, bg)
        local function row(yy, l1, f1, b1c, fn1, l2, f2, b2c, fn2)
            ui:fill(b1, yy, bw, 1, b1c) ui:center(b1, yy, bw, l1, f1, b1c) ui:hit(b1, yy, b1 + bw - 1, yy, fn1)
            ui:fill(b2, yy, bw, 1, b2c) ui:center(b2, yy, bw, l2, f2, b2c) ui:hit(b2, yy, b2 + bw - 1, yy, fn2)
        end
        row(by, "DIAL", colors.black, colors.orange, function() overlay = { page = 1 } book:reload() end,
            dial.active and "ABORT" or "CLOSE", colors.white, colors.red, closeGate)
        row(by + 1, "IRIS", colors.black, gate and gate.hasIris and colors.lightGray or colors.gray, toggleIris,
            "STYLE", colors.black, colors.lightGray, cycleStyle)
    end
end

local function drawOverlay()
    local x, y, w, h = L.gx, L.gy, L.gw, L.gh
    ui:fill(x, y, w, h, colors.black)
    ui:fill(x, y, w, 1, colors.orange)
    ui:write(x + 1, y, fit("SELECT DESTINATION", w - 2), colors.black, colors.orange)
    local entries = book.entries
    local per = math.max(1, math.floor((h - 3) / 2))
    local pages = math.max(1, math.ceil(#entries / per))
    overlay.page = math.max(1, math.min(overlay.page, pages))
    local first = (overlay.page - 1) * per + 1
    for i = 0, per - 1 do
        local e = entries[first + i]
        if not e then break end
        local ry = y + 1 + i * 2
        local planned = e.address == nil
        local rowBg = i % 2 == 0 and colors.black or colors.gray
        ui:fill(x, ry, w, 2, rowBg)
        ui:write(x + 1, ry, fit(e.name, w - 2), planned and colors.lightGray or colors.white, rowBg)
        local addr = planned and "no address yet" or A.format(e.address)
        ui:write(x + 1, ry + 1, fit(addr, w - 2), planned and colors.gray or colors.orange, rowBg)
        if e.note ~= "" and #addr + 4 < w - 2 then
            ui:write(x + 2 + #addr, ry + 1, fit(" " .. e.note, w - 3 - #addr), colors.lightGray, rowBg)
        end
        ui:hit(x, ry, x + w - 1, ry + 1, function()
            overlay = nil
            paintBackground()
            startDial(e)
        end)
    end
    if #entries == 0 then ui:center(x, y + 2, w, "The address book is empty", colors.lightGray, colors.black) end
    local by = y + h - 1
    ui:fill(x, by, w, 1, colors.gray)
    local bx = x + 1
    bx = ui:button(bx, by, " \30 ", colors.white, colors.gray, function() overlay.page = overlay.page - 1 end) + 1
    ui:write(bx, by, overlay.page .. "/" .. pages, colors.lightGray, colors.gray)
    bx = bx + #(overlay.page .. "/" .. pages) + 1
    ui:button(bx, by, " \31 ", colors.white, colors.gray, function() overlay.page = overlay.page + 1 end)
    ui:button(x + w - 9, by, " CANCEL ", colors.white, colors.red, function() overlay = nil paintBackground() end)
end

local function drawGate(t)
    local syms, total, lit = chevronPlan()
    local glyphs = {}
    -- numbered symbols can be lit on the ring (Pegasus / Universe looks)
    if gate and gate.originSymbol == 0 then
        for _, s in ipairs(gate.engaged) do glyphs[s] = true end
        if gate.connected and gate.remote then for _, s in ipairs(A.symbols(gate.remote)) do glyphs[s] = true end end
    end
    local chase
    if gate and (gate.state == "DIALING" or (gate.state == "INCOMING" and not gate.connected)) then chase = (t * 200) % 360 end
    local view = {
        t = t,
        symbols = gate and gate.symbolCount or 39,
        rotation = rotation,
        lit = lit, total = total,
        glyphs = glyphs, chase = chase,
        openedAt = gate and gate.connected and gate.openedAt or nil,
        closingAt = gate and not gate.connected and gate.closingAt or nil,
        iris = gate and gate.iris,
    }
    ring:draw(style, view)
    canvas:draw(target, L.gx, L.gy)
end

local function drawNative()
    if not monitor then return end
    native.setBackgroundColor(colors.black)
    native.clear()
    local lines = {
        { "Gate Room " .. VERSION .. " is running on " .. monitorName, colors.white },
        { "", colors.white },
        { "Touch the monitor to dial, close or use the iris.", colors.lightGray },
        { "Or type an address here and press Enter:", colors.lightGray },
        { "  26 6 14 31 11 29        Stargate Journey, Lantea", colors.gray },
        { "  WLDQ-DQB-MT             SGCraft", colors.gray },
        { "  Crater, Virgo, Bootes.. JSG (names, commas)", colors.gray },
        { "", colors.white },
        { "> " .. manual, colors.orange },
        { "", colors.white },
        { "Ctrl+X close gate   Ctrl+I iris   Ctrl+S style", colors.lightGray },
        { "Ctrl+Q quit", colors.lightGray },
    }
    for i, l in ipairs(lines) do
        native.setCursorPos(1, i)
        native.setTextColor(l[2])
        native.write(l[1])
    end
    native.setCursorPos(3 + #manual, 9)
    native.setTextColor(colors.white)
    native.setCursorBlink(true)
end

local function draw()
    local t = os.clock()
    updateRotation(t)
    ui:clearHits()
    drawHeader(t)
    if overlay then
        drawOverlay()
    else
        drawGate(t)
        ui:hit(L.gx, L.gy, L.gx + L.gw - 1, L.gy + L.gh - 1, toggleIris)
    end
    drawPanel(t)
    lastFrame = t
end

---------------------------------------------------------------------------
-- Alarm (incoming wormholes)
---------------------------------------------------------------------------

local function updateAlarm(t)
    local on = gate ~= nil and gate.state == "INCOMING" and (not gate.connected or (gate:openSeconds() or 99) < 5)
    if on ~= alarm.on then
        alarm.on = on
        if CONFIG.alarmSide then redstone.setOutput(CONFIG.alarmSide, on) end
    end
    if on and CONFIG.klaxon and speaker and t - alarm.lastBeep >= 0.5 then
        alarm.lastBeep = t
        alarm.beep = alarm.beep + 1
        pcall(speaker.playNote, "bit", 1, alarm.beep % 2 == 0 and 6 or 11)
    end
end

---------------------------------------------------------------------------
-- Tasks
---------------------------------------------------------------------------

local function dialerTask()
    while true do
        os.pullEvent("gateroom_dial")
        local ok, why = gate:dial(dial.address, {
            fast = CONFIG.fastDial, symbolDelay = CONFIG.symbolDelay, chevronDelay = CONFIG.chevronDelay,
            stepTimeout = CONFIG.stepTimeout, connectTimeout = CONFIG.connectTimeout,
            abort = function() return dial.abort end,
            onStep = function() os.queueEvent("gateroom_redraw") end,
        })
        local entry = dial.entry
        if ok then
            setMessage("Wormhole established" .. (entry and (" to " .. entry.name) or ""), colors.lightBlue)
            if entry then entry.last = "ok" end
        elseif why == "aborted" then
            setMessage("Dialing aborted", colors.orange)
        else
            setMessage("Dialing failed: " .. tostring(why), colors.red)
            if entry then entry.last = "fail" end
        end
        if entry then book:save() end
        dial.active, dial.abort = false, false
        dial.endedAt, dial.failed = os.clock(), not ok
        gate:poll()
        os.queueEvent("gateroom_redraw")
    end
end

local function onGateEvent(info)
    if not info then return end
    local ty = info.type
    if ty == "chevron" and info.incoming and not info.unset then
        if dial.active then dial.abort = true end
        if CONFIG.autoIris and gate.hasIris and (gate.iris or 0) < 100 and info.n == 1 then
            gate:closeIris()
            setMessage("Unscheduled offworld activation - closing the iris", colors.red)
        else
            setMessage("Unscheduled offworld activation", colors.red)
        end
    elseif ty == "dialin" then
        if CONFIG.autoIris and gate.hasIris and (gate.iris or 0) < 100 then gate:closeIris() end
        setMessage("Unscheduled offworld activation", colors.red)
    elseif ty == "incoming" then
        local who = info.address and book:describe(info.address)
        setMessage("Incoming wormhole" .. (who and (" from " .. who) or ""), colors.red)
        if CONFIG.autoIris and gate.hasIris and (gate.iris or 0) < 100 then gate:closeIris() end
    elseif ty == "outgoing" then
        local who = (dial.entry and dial.entry.name) or (info.address and book:describe(info.address))
        setMessage("Wormhole established" .. (who and (" to " .. who) or ""), colors.lightBlue)
    elseif ty == "closed" or ty == "reset" then
        if autoCloseTimer then os.cancelTimer(autoCloseTimer) autoCloseTimer = nil end
        if os.clock() - dial.endedAt < 2 then
            -- the gate resetting after our own dial: keep its result, with the gate's reason if it has one
            if dial.failed and info.error and info.reason then setMessage("Dialing failed: " .. info.reason, colors.red) end
        elseif not dial.active then
            if info.error then setMessage("Gate reset: " .. tostring(info.reason), colors.red)
            else setMessage("Wormhole closed" .. (info.reason and (": " .. info.reason) or ""), colors.lightGray) end
        end
    elseif ty == "traveler" then
        local name = info.name and tostring(info.name) or "Traveller"
        if info.direction == "out" then
            setMessage(name .. " stepped through the gate", colors.lightBlue)
            if CONFIG.autoClose > 0 and gate.outgoing and not autoCloseTimer then
                autoCloseTimer = os.startTimer(CONFIG.autoClose)
            end
        else
            setMessage(name .. " came through the gate", colors.lightBlue)
        end
    elseif ty == "thud" then
        setMessage("Something hit the iris", colors.red)
    elseif ty == "rotation" then
        rotating = info.started
        if not info.started then rotation = gate:rotation() or rotation end
    elseif ty == "iris" then
        setMessage("Iris " .. tostring(info.state):lower(), colors.lightGray)
    elseif ty == "message" then
        setMessage("Message: " .. info.text, colors.yellow)
    end
end

local function dialManual()
    local address, why = A.parse(manual)
    if not address then setMessage(why, colors.red) return end
    manual = ""
    startDial(book:find(address), address)
end

local function keyEvent(e, held)
    local ctrl = held[keys.leftCtrl] or held[keys.rightCtrl]
    if e[1] == "key" then
        local k = e[2]
        if ctrl and k == keys.x then closeGate()
        elseif ctrl and k == keys.i then toggleIris()
        elseif ctrl and k == keys.s then cycleStyle()
        elseif ctrl and k == keys.d then overlay = { page = 1 } book:reload()
        elseif ctrl and k == keys.q then quit()
        elseif k == keys.backspace then manual = manual:sub(1, -2)
        elseif k == keys.enter or k == keys.numPadEnter then
            if manual ~= "" then dialManual() end
        elseif overlay and k == keys.up then overlay.page = overlay.page - 1
        elseif overlay and k == keys.down then overlay.page = overlay.page + 1
        elseif k == keys.escape and overlay then overlay = nil paintBackground()
        end
    elseif (e[1] == "char" or e[1] == "paste") and not ctrl then
        local s = tostring(e[2]):gsub("[^%w%s%-,]", "")
        manual = (manual .. s):sub(1, 40)
    end
end

local function uiTask()
    local held = {}
    local frameTimer = os.startTimer(0)
    local nativeDirty = true
    local pollTimer = os.startTimer(CONFIG.pollInterval)
    while running do
        local e = table.pack(os.pullEventRaw())
        local name = e[1]
        local redraw = false
        if name == "terminate" then
            quit()
        elseif name == "timer" then
            if e[2] == frameTimer then
                frameTimer = nil
                redraw = true
            elseif e[2] == pollTimer then
                if gate then gate:poll() end
                pollTimer = os.startTimer(CONFIG.pollInterval)
                redraw = true
            elseif e[2] == autoCloseTimer then
                autoCloseTimer = nil
                if gate and gate.state == "OPEN" then
                    gate:close()
                    setMessage("Wormhole closed by auto-close", colors.lightGray)
                end
                redraw = true
            end
        elseif gate and Gate.EVENTS[name] then
            onGateEvent(gate:event(e))
            redraw = true
        elseif name == "peripheral" then
            if not gate and Gate.isInterfaceType(peripheral.getType(e[2])) then
                gate = Gate.find(CONFIG.interfaceName)
                chooseStyle()
                setMessage(gate and "Stargate interface connected" or "", colors.lime)
                redraw = true
            end
            if not speaker and peripheral.getType(e[2]) == "speaker" then speaker = peripheral.wrap(e[2]) end
        elseif name == "peripheral_detach" then
            if gate and e[2] == gate.name then
                if dial.active then dial.abort = true end
                gate = nil
                chooseStyle()
                setMessage("Stargate interface disconnected", colors.red)
                redraw = true
            elseif monitorName and e[2] == monitorName then
                running = false
            end
        elseif name == "monitor_touch" then
            if e[2] == monitorName then ui:click(e[3], e[4], 1) redraw = true end
        elseif name == "mouse_click" then
            if not monitor then ui:click(e[3], e[4], e[2]) redraw = true end
        elseif name == "key" or name == "key_up" then
            if name == "key" then
                held[e[2]] = true
                keyEvent(e, held)
                redraw, nativeDirty = true, true
            else
                held[e[2]] = nil
            end
        elseif name == "char" or name == "paste" then
            keyEvent(e, held)
            redraw, nativeDirty = true, true
        elseif name == "monitor_resize" or name == "term_resize" then
            layout()
            redraw = true
        elseif name == "gateroom_redraw" then
            redraw = true
        end

        if running and redraw then
            updateAlarm(os.clock())
            draw()
            if nativeDirty then
                drawNative()
                nativeDirty = false
            end
            -- keep animating while something moves; the poll timer redraws otherwise
            if not frameTimer and animating() then
                frameTimer = os.startTimer(CONFIG.frameTime)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

chooseStyle()
layout()
if book.notice then
    setMessage(book.notice, colors.yellow)
elseif not gate then
    setMessage("No stargate interface found - attach one", colors.red)
else
    setMessage("Ready. DIAL to pick a destination.", colors.lightGray)
end

local ok, err = pcall(parallel.waitForAny, uiTask, dialerTask)

if CONFIG.alarmSide then redstone.setOutput(CONFIG.alarmSide, false) end
Styles.reset(target)
target.setBackgroundColor(colors.black)
target.setTextColor(colors.white)
target.clear()
target.setCursorPos(1, 1)
if monitor then
    native.setBackgroundColor(colors.black)
    native.clear()
    native.setCursorPos(1, 1)
end
native.setCursorBlink(false)
if not ok and err ~= "Terminated" then
    printError(err)
else
    print("Gate Room closed.")
end
