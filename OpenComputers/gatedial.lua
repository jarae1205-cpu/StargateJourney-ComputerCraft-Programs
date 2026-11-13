--
-- gatedial - a stargate dialing computer for OpenComputers (OpenOS)
--
-- For SGCraft (Greg Ewing's, and SGCraft 2.x) and Just Stargate Mod 1.12.2, through the
-- gate's "stargate" component. Uses the same address book (dialer_addresses.db), trusted
-- iris codes (iris_codes.db) and gate log (gate_log.db) as the ComputerCraft programs.
--
--   Up / Down   pick an address          Enter   dial it
--   X           close the wormhole       I       open or close the iris
--   N           new address              E       edit       D   delete
--   L           the gate log             Q       quit
--
-- Touch works too: tap an address to pick it, tap it again to dial.
--

local VERSION = "1.0"

--
-- CONFIGURATION
--
local CONFIG = {
    dataFile = "dialer_addresses.db",
    codesFile = "iris_codes.db",
    logFile = "gate_log.db",
    -- open the iris when the gate that dialed in sends a trusted code (see the idc program)
    irisCodes = true,
    -- close the iris when another gate dials in
    autoIris = false,
    -- beep while another gate is dialing in
    alarm = true,
    -- draw the gate next to the list (needs a tier 3 screen and graphics card)
    gatePicture = true,
    -- seconds between gate checks
    pollInterval = 1,
}
--
-- END OF CONFIGURATION
--

local OC = require("sgc.oc")
OC.install()

local component = require("component")
local computer = require("computer")
local event = require("event")
local keyboard = require("keyboard")
local term = require("term")
local unicode = require("unicode")
local hasThread, thread = pcall(require, "thread")

local A = require("sgc.address")
local Book = require("sgc.book")
local CallLog = require("sgc.calllog")
local Gate = require("sgc.gate")
local IDC = require("sgc.idc")
local Pixels = require("sgc.pixels")
local Ring = require("sgc.ring")
local Styles = require("sgc.styles")

local gpu = component.gpu
local oldW, oldH = gpu.getResolution()
local W, H = gpu.maxResolution()
gpu.setResolution(W, H)
local depth = gpu.getDepth()
local paletteColors = depth >= 4
local oldPalette = {}
if paletteColors then
    for i = 0, 15 do oldPalette[i] = gpu.getPaletteColor(i) end
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function index(c)
    return math.floor(math.log(c) / math.log(2) + 0.5)
end

local curFg, curBg
local function setFg(c)
    if c == curFg then return end
    curFg = c
    if paletteColors then gpu.setForeground(index(c), true)
    else gpu.setForeground(c == colors.black and 0x000000 or 0xFFFFFF) end
end
local function setBg(c)
    if c == curBg then return end
    curBg = c
    if paletteColors then gpu.setBackground(index(c), true)
    else gpu.setBackground(c == colors.black and 0x000000 or (c == colors.white and 0xFFFFFF or 0x000000)) end
end

local function fit(s, n)
    s = tostring(s or "")
    local len = unicode.len(s)
    if len > n then return unicode.sub(s, 1, math.max(0, n)) end
    return s .. (" "):rep(n - len)
end

local function text(x, y, s, fg, bg)
    setFg(fg or colors.white)
    setBg(bg or colors.black)
    gpu.set(x, y, s)
end

local function fill(x, y, w, h, bg)
    if w < 1 or h < 1 then return end
    setBg(bg or colors.black)
    gpu.fill(x, y, w, h, " ")
end

local hits = {}
local function hit(x1, y1, x2, y2, fn) hits[#hits + 1] = { x1, y1, x2, y2, fn } end
local function button(x, y, label, fg, bg, fn)
    text(x, y, label, fg, bg)
    hit(x, y, x + unicode.len(label) - 1, y, fn)
    return x + unicode.len(label)
end

local function applyPalette(map)
    if not paletteColors then return end
    for i = 0, 15 do gpu.setPaletteColor(i, OC.PALETTE[i]) end
    for c, hex in pairs(map or {}) do gpu.setPaletteColor(index(c), hex) end
    curFg, curBg = nil, nil
end

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local book = Book.open(CONFIG.dataFile)
local log = CallLog.open(CONFIG.logFile)
local gate = Gate.find()
local style = Styles.forGate(gate)
local sel, scroll = 1, 0
local view = "list" -- or "log"
local logPage = 1
local message = { text = "", color = colors.lightGray }
local dial = { active = false, abort = false, entry = nil, address = nil, endedAt = -10, failed = false }
local call = nil
local running = true
local dirty, full = true, true
local alarmBeep = 0
local lastTap = { row = nil, t = 0 }
local L = {}
local canvas, ring
local pictureAt = 0

local function setMessage(s, c)
    message.text, message.color = s or "", c or colors.lightGray
    dirty = true
end

local function entries()
    return book:visible(gate and gate.localAddress)
end

local function logCall(e)
    pcall(log.add, log, e)
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

local function layout()
    L.picture = CONFIG.gatePicture and paletteColors and W >= 100 and H >= 30
    L.listW = L.picture and math.floor(W * 0.45) or W
    L.listY = 3
    L.listH = H - 7
    L.chevronY = H - 3
    L.stateY = H - 2
    L.messageY = H - 1
    L.buttonY = H
    if L.picture then
        L.picX, L.picY = L.listW + 2, 3
        L.picW, L.picH = W - L.listW - 2, H - 7
        canvas = Pixels.newHalf(L.picW, L.picH, colors.black)
        ring = Ring.new(canvas, canvas.w / 2, canvas.h / 2 + 0.5, math.min(canvas.w, canvas.h) / 2 / 1.1)
    end
end

---------------------------------------------------------------------------
-- The gate
---------------------------------------------------------------------------

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
    return syms, total, math.min(lit, total)
end

local function shortSymbol(s)
    if type(s) == "number" then return s == 0 and "PoO" or tostring(s) end
    if type(s) == "string" then
        if A.isOriginName(s) then return "PoO" end
        return s:sub(1, 3)
    end
    return "?"
end

local function sendCode(entry)
    if not (entry and entry.idc) then return end
    local ok, why = gate:sendMessage(IDC.message(entry.idc))
    if ok then setMessage("Wormhole established to " .. entry.name .. " - iris code sent", colors.lightBlue)
    else setMessage("Wormhole established to " .. entry.name .. " - could not send the iris code: " .. tostring(why), colors.orange) end
end

local function onCode(code)
    if not CONFIG.irisCodes or gate.outgoing then return end
    local trusted = IDC.check(IDC.load(CONFIG.codesFile), code)
    if trusted then
        local who = trusted.name ~= "" and trusted.name or ("code " .. code)
        local opening = gate.hasIris and (gate.iris or 0) > 0
        if opening then gate:openIris() end
        gate:sendMessage("IDC:ACCEPTED " .. who)
        setMessage("Iris code " .. code .. " accepted: " .. who .. (opening and " - opening the iris" or ""), colors.lime)
        logCall({ kind = "code", text = code .. " accepted (" .. who .. ")" })
    else
        gate:sendMessage("IDC:REJECTED")
        setMessage("Unknown iris code " .. code .. (gate.hasIris and " - the iris stays closed" or ""), colors.red)
        logCall({ kind = "code", text = code .. " rejected" })
    end
end

local function beginCall(kind, name, address)
    call = { name = name, address = address, start = computer.uptime() }
    logCall({ kind = kind, name = name, address = address })
end

local function onGateEvent(info)
    if not info then return end
    local ty = info.type
    if (ty == "chevron" and info.incoming) or ty == "dialin" then
        if dial.active then dial.abort = true end
        if CONFIG.autoIris and gate.hasIris and (gate.iris or 0) < 100 then gate:closeIris() end
        setMessage("Unscheduled offworld activation", colors.red)
    elseif ty == "incoming" then
        local who = info.address and book:describe(info.address)
        setMessage("Incoming wormhole" .. (who and (" from " .. who) or ""), colors.red)
        if CONFIG.autoIris and gate.hasIris and (gate.iris or 0) < 100 then gate:closeIris() end
        beginCall("in", info.address and book:find(info.address) and who or nil, info.address)
    elseif ty == "outgoing" then
        if not dial.active and computer.uptime() - dial.endedAt > 2 then
            local entry = info.address and book:find(info.address)
            beginCall("out", entry and entry.name, info.address)
            sendCode(entry)
        end
    elseif ty == "closed" or ty == "reset" then
        if call and ty == "closed" then
            logCall({ kind = "closed", name = call.name, address = call.address, seconds = computer.uptime() - call.start, text = info.reason })
        end
        call = nil
        if not dial.active and computer.uptime() - dial.endedAt > 2 then
            if info.error then setMessage("Gate reset: " .. tostring(info.reason), colors.red)
            else setMessage("Wormhole closed" .. (info.reason and (": " .. info.reason) or ""), colors.lightGray) end
        end
    elseif ty == "traveler" then
        local name = info.name and tostring(info.name) or "Traveller"
        logCall({ kind = "traveler", text = (info.direction == "out" and "out: " or "in: ") .. name })
        setMessage(name .. (info.direction == "out" and " stepped through the gate" or " came through the gate"), colors.lightBlue)
    elseif ty == "thud" then
        setMessage("Something hit the iris", colors.red)
    elseif ty == "message" then
        local kind, value = IDC.parse(info.text)
        if kind == "code" then onCode(value)
        elseif kind == "accepted" then
            setMessage("Iris code accepted" .. (value and (" as " .. value) or "") .. " - the way is open", colors.lime)
            logCall({ kind = "code", text = "our code accepted" })
        elseif kind == "rejected" then
            setMessage("Iris code rejected - their iris stays closed", colors.red)
            logCall({ kind = "code", text = "our code rejected" })
        else
            setMessage("Message: " .. tostring(info.text), colors.yellow)
        end
    end
    dirty = true
end

local function runDial()
    local ok, why = gate:dial(dial.address, {
        abort = function() return dial.abort end,
        onStep = function() dirty = true computer.pushSignal("gatedial_redraw") end,
    })
    local entry = dial.entry
    if ok then
        setMessage("Wormhole established" .. (entry and (" to " .. entry.name) or ""), colors.lightBlue)
        if entry then entry.last = "ok" end
        beginCall("out", entry and entry.name, dial.address)
        sendCode(entry)
    elseif why == "aborted" then
        setMessage("Dialing aborted", colors.orange)
    else
        setMessage("Dialing failed: " .. tostring(why), colors.red)
        if entry then entry.last = "fail" end
        logCall({ kind = "fail", name = entry and entry.name, address = dial.address, text = tostring(why) })
    end
    if entry then book:save() end
    dial.active, dial.abort = false, false
    dial.endedAt, dial.failed = computer.uptime(), not ok
    gate:poll()
    dirty = true
    computer.pushSignal("gatedial_redraw")
end

local function startDial(entry)
    if not gate then setMessage("No stargate connected", colors.red) return end
    if not (entry and entry.address) then setMessage("That entry has no address yet", colors.orange) return end
    if dial.active then setMessage("Already dialing - X aborts", colors.orange) return end
    gate:poll()
    if gate.state ~= "IDLE" then setMessage("The gate is busy", colors.red) return end
    local dialable, why = A.dialableBy(entry.address, gate.mod)
    if not dialable then setMessage(why, colors.red) return end
    dial.active, dial.abort, dial.entry, dial.address = true, false, entry, entry.address
    gate.remote, gate.outgoing = entry.address, true
    setMessage("Dialing " .. entry.name, colors.lightGray)
    if hasThread then thread.create(runDial) else runDial() end
end

local function closeGate()
    if dial.active then dial.abort = true setMessage("Aborting dial...", colors.orange) return end
    if not gate then return end
    gate:poll()
    if gate.state == "IDLE" then setMessage("The gate is already idle", colors.gray) return end
    local ok, why = gate:close()
    if ok == false and why then setMessage(tostring(why), colors.red)
    else setMessage("Closing the gate", colors.lightGray) end
end

local function toggleIris()
    if not (gate and gate.hasIris) then setMessage("This gate has no iris", colors.gray) return end
    gate:poll()
    if (gate.iris or 0) >= 50 then gate:openIris() setMessage("Opening the iris", colors.lightGray)
    else gate:closeIris() setMessage("Closing the iris", colors.lightGray) end
end

---------------------------------------------------------------------------
-- Screens
---------------------------------------------------------------------------

local STATE_COLORS = { IDLE = colors.gray, DIALING = colors.orange, OPEN = colors.lightBlue, INCOMING = colors.red,
    CLOSING = colors.lightGray, OFFLINE = colors.gray }

local function drawHeader()
    fill(1, 1, W, 1, colors.gray)
    local title = " STARGATE COMMAND"
    if gate then
        local addr = gate.localAddress and A.format(gate.localAddress)
        -- on a narrow screen JSG's symbol names are shortened: Aqu-Cet-Gem-Leo-Sco-Ori
        if addr and unicode.len(title .. gate.typeName .. addr) + 4 > W - 12 and A.kind(gate.localAddress) == "names" then
            local short = {}
            for i, s in ipairs(A.strip(gate.localAddress)) do short[i] = unicode.sub(tostring(s), 1, 3) end
            addr = table.concat(short, "-")
        end
        title = title .. "  " .. gate.typeName .. (addr and ("  " .. addr) or "")
    end
    text(1, 1, fit(title, W - 12), colors.white, colors.gray)
    local st = gate and gate.state or "NO GATE"
    text(W - 11, 1, fit(" " .. st, 11), colors.black, STATE_COLORS[st] or colors.gray)
end

local function drawList()
    local list = entries()
    sel = math.max(1, math.min(sel, math.max(1, #list)))
    if sel <= scroll then scroll = sel - 1 end
    if sel > scroll + L.listH then scroll = sel - L.listH end
    fill(1, L.listY - 1, L.listW, 1, colors.black)
    text(1, L.listY - 1, fit(" ADDRESS BOOK (" .. #list .. ")", L.listW), colors.orange, colors.black)
    for row = 1, L.listH do
        local i = scroll + row
        local e = list[i]
        local y = L.listY + row - 1
        local bg = (i == sel) and colors.gray or colors.black
        if e then
            local addr = e.address and A.format(e.address) or "no address yet"
            local nameW = math.max(8, L.listW - unicode.len(addr) - 4)
            text(1, y, fit(" " .. e.name, nameW), e.last == "fail" and colors.red or colors.white, bg)
            text(nameW + 1, y, fit(" " .. addr, L.listW - nameW), e.address and colors.orange or colors.gray, bg)
            hit(1, y, L.listW, y, function()
                local now = computer.uptime()
                if lastTap.row == i and now - lastTap.t < 1.5 then startDial(e) end
                sel, lastTap.row, lastTap.t = i, i, now
                dirty = true
            end)
        else
            fill(1, y, L.listW, 1, colors.black)
        end
    end
end

local LOG_COLORS = { ["in"] = colors.red, out = colors.lightBlue, fail = colors.orange, closed = colors.lightGray,
    traveler = colors.white, code = colors.lime }

local function drawLog()
    local per = L.listH
    local pages = math.max(1, math.ceil(#log.entries / per))
    logPage = math.max(1, math.min(logPage, pages))
    fill(1, L.listY - 1, L.listW, 1, colors.black)
    text(1, L.listY - 1, fit(" GATE LOG  page " .. logPage .. "/" .. pages .. "  (L: back, Up/Down: pages)", L.listW), colors.orange, colors.black)
    for row = 1, per do
        local e = log.entries[(logPage - 1) * per + row]
        local y = L.listY + row - 1
        fill(1, y, L.listW, 1, colors.black)
        if e then
            local when, label, info = CallLog.describe(e)
            text(2, y, fit(label, 6), LOG_COLORS[e.kind] or colors.white, colors.black)
            text(8, y, fit(when, 14), colors.lightGray, colors.black)
            text(23, y, fit(info, L.listW - 23), colors.white, colors.black)
        end
    end
    if #log.entries == 0 then text(2, L.listY, "Nothing has gone through the gate yet", colors.lightGray, colors.black) end
end

local function drawPicture()
    if not L.picture or not gate then return end
    local t = computer.uptime()
    local syms, total, lit = chevronPlan()
    canvas:clear(colors.black)
    if style.stars or style.backdrop then
        for y = 1, canvas.h do
            for x = 1, canvas.w do
                local c = Ring.backdropAt(style, x, y, ring.cx, ring.cy, ring.R)
                if c then canvas:set(x, y, c) end
            end
        end
    end
    local glyphs = {}
    if gate.originSymbol == 0 then for _, s in ipairs(gate.engaged) do glyphs[s] = true end end
    ring:draw(style, {
        t = t, symbols = gate.symbolCount or 39, rotation = gate:rotation() or 0,
        lit = lit, total = total, glyphs = glyphs,
        chase = (gate.state == "DIALING" or (gate.state == "INCOMING" and not gate.connected)) and (t * 200) % 360 or nil,
        openedAt = gate.connected and gate.openedAt or nil,
        closingAt = not gate.connected and gate.closingAt or nil,
        iris = gate.iris,
    })
    canvas:drawHalf(function(x, y, s, fgi, bgi)
        setFg(2 ^ fgi)
        setBg(2 ^ bgi)
        gpu.set(x, y, s)
    end, L.picX, L.picY)
    pictureAt = t
end

local function drawStatus()
    -- chevrons
    fill(1, L.chevronY, W, 1, colors.black)
    local syms, total, lit = chevronPlan()
    local x = 2
    for i = 1, total do
        local on = i <= lit
        local label = "\226\150\188" .. (syms[i] ~= nil and shortSymbol(syms[i]) or "")
        if x + unicode.len(label) > W then break end
        text(x, L.chevronY, label, on and (i == total and colors.red or colors.orange) or colors.gray, colors.black)
        x = x + unicode.len(label) + 1
    end
    -- state line
    fill(1, L.stateY, W, 1, colors.black)
    if gate then
        local s = gate.state
        if gate.connected then
            local secs = math.floor(gate:openSeconds() or 0)
            local who = gate.remote and book:describe(gate.remote)
            s = (gate.outgoing and "Wormhole open" .. (who and (" to " .. who) or "") or "Incoming wormhole" .. (who and (" from " .. who) or ""))
                .. string.format("  %02d:%02d", math.floor(secs / 60), secs % 60)
        elseif dial.active then
            s = "Dialing " .. (dial.entry and dial.entry.name or A.format(dial.address))
        end
        local iris = gate.hasIris and (gate.iris == nil and "?" or (gate.iris >= 100 and "closed" or (gate.iris <= 0 and "open" or "moving"))) or "none"
        local energy = gate.energy and string.format("  Energy %.0f %s", gate.energy, gate.energyUnit or "") or ""
        text(2, L.stateY, fit(s .. "   Iris: " .. iris .. energy, W - 2), STATE_COLORS[gate.state] or colors.white, colors.black)
    else
        text(2, L.stateY, "No stargate component - connect the computer to the gate", colors.red, colors.black)
    end
    -- message
    fill(1, L.messageY, W, 1, colors.black)
    text(2, L.messageY, fit(message.text, W - 2), message.color, colors.black)
    -- buttons
    fill(1, L.buttonY, W, 1, colors.gray)
    local bx = 2
    local list = entries()
    bx = button(bx, L.buttonY, " Dial ", colors.black, colors.orange, function() startDial(list[sel]) end) + 1
    bx = button(bx, L.buttonY, dial.active and " Abort " or " Close ", colors.white, colors.red, closeGate) + 1
    bx = button(bx, L.buttonY, " Iris ", colors.black, colors.lightGray, toggleIris) + 1
    bx = button(bx, L.buttonY, view == "log" and " List " or " Log ", colors.black, colors.lightGray, function()
        view = view == "log" and "list" or "log"
        full = true
    end) + 1
    bx = button(bx, L.buttonY, " Quit ", colors.white, colors.gray, function() running = false end)
    text(math.max(bx + 2, W - 30), L.buttonY, fit("N new  E edit  D delete", math.min(30, W - bx - 2)), colors.lightGray, colors.gray)
end

local function draw()
    hits = {}
    if full then
        fill(1, 1, W, H, colors.black)
        if canvas then canvas:invalidate() end
        full = false
    end
    drawHeader()
    if view == "log" then drawLog() else drawList() end
    drawPicture()
    drawStatus()
    dirty = false
end

---------------------------------------------------------------------------
-- Editing (typed on the computer)
---------------------------------------------------------------------------

-- OpenOS can't put text in the input line to start with (term.read's first argument is
-- a history), so the current value is shown in [brackets]: Enter keeps it, "-" clears it
local function prompt(label, current)
    if current == "" then current = nil end
    if current then
        local shown = unicode.len(current) > 40 and (unicode.sub(current, 1, 37) .. "...") or current
        label = label .. " [" .. shown .. "]"
    end
    fill(1, L.messageY, W, 1, colors.black)
    text(2, L.messageY, label .. ": ", colors.yellow, colors.black)
    term.setCursor(4 + unicode.len(label), L.messageY)
    setFg(colors.white)
    local line = term.read({ current }, false)
    if not line then return nil end
    line = line:gsub("[\r\n]+$", "")
    if line == "" and current then return current end
    if line == "-" then return "" end
    return line
end

local function editEntry(entry)
    local name = prompt("Name", entry and entry.name)
    if not name then setMessage("Cancelled") return end
    local addrText = prompt(entry and entry.address and "Address" or "Address (empty for a planned one)", entry and entry.address and A.format(entry.address))
    if not addrText then setMessage("Cancelled") return end
    local address
    if addrText:match("%S") then
        local why
        address, why = A.parse(addrText)
        if not address then setMessage(why, colors.red) return end
    end
    local code = prompt(entry and entry.idc and "Iris code" or "Iris code to send (empty for none)", entry and entry.idc)
    if code == nil then setMessage("Cancelled") return end
    local data = { name = name ~= "" and name or (address and A.format(address)), address = address, note = entry and entry.note or "",
        group = entry and entry.group, color = entry and entry.color, idc = code, home = entry and entry.home }
    local clean = Book.clean(data)
    if not clean then setMessage("Give it a name or an address", colors.red) return end
    if code:match("%S") and not clean.idc then setMessage("An iris code is 1-16 letters, digits or dashes", colors.red) return end
    if entry then
        for k in pairs(entry) do entry[k] = nil end
        for k, v in pairs(clean) do entry[k] = v end
    else
        book.entries[#book.entries + 1] = clean
    end
    book:save()
    setMessage("Saved " .. clean.name, colors.lime)
    full = true
end

local function deleteEntry(entry)
    if not entry then return end
    local answer = prompt("Delete " .. entry.name .. "? (y/n)")
    if answer and answer:lower():sub(1, 1) == "y" then
        for i, e in ipairs(book.entries) do
            if e == entry then table.remove(book.entries, i) break end
        end
        book:save()
        setMessage("Deleted " .. entry.name, colors.lightGray)
    else
        setMessage("Kept " .. entry.name)
    end
    full = true
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

local function onKey(char, code)
    local list = entries()
    local k = keyboard.keys
    if view == "log" then
        if code == k.up or code == k.pageUp then logPage = logPage - 1
        elseif code == k.down or code == k.pageDown then logPage = logPage + 1
        elseif code == k.l or code == k.back then view = "list" full = true
        elseif code == k.q then running = false end
        dirty = true
        return
    end
    if code == k.up then sel = sel - 1
    elseif code == k.down then sel = sel + 1
    elseif code == k.pageUp then sel = sel - L.listH
    elseif code == k.pageDown then sel = sel + L.listH
    elseif code == k.enter or code == k.numpadenter then startDial(list[sel])
    elseif code == k.x then closeGate()
    elseif code == k.i then toggleIris()
    elseif code == k.l then view = "log" full = true
    elseif code == k.n then editEntry(nil)
    elseif code == k.e then editEntry(list[sel])
    elseif code == k.d then deleteEntry(list[sel])
    elseif code == k.q then running = false
    end
    dirty = true
end

local function onTouch(x, y)
    for i = #hits, 1, -1 do
        local h = hits[i]
        if x >= h[1] and x <= h[3] and y >= h[2] and y <= h[4] then h[5]() dirty = true return end
    end
end

---------------------------------------------------------------------------
-- Run
---------------------------------------------------------------------------

-- gate signals are collected by listeners, so none are missed while a gate call is waiting
local queue = {}
local listeners = {}
for name in pairs(Gate.EVENTS) do
    local fn = function(...) queue[#queue + 1] = table.pack(...) end
    listeners[name] = fn
    event.listen(name, fn)
end

local function cleanup()
    for name, fn in pairs(listeners) do event.ignore(name, fn) end
    if paletteColors then for i = 0, 15 do gpu.setPaletteColor(i, oldPalette[i]) end end
    gpu.setForeground(0xFFFFFF)
    gpu.setBackground(0x000000)
    gpu.setResolution(oldW, oldH)
    term.clear()
    OC.uninstall()
end

local function main()
    applyPalette(style.palette)
    layout()
    if book.notice then setMessage(book.notice, colors.yellow)
    elseif not gate then setMessage("No stargate component found - connect the computer to the gate", colors.red)
    else setMessage("Ready. Enter dials the selected address.", colors.lightGray) end
    local nextPoll = 0
    while running do
        if dirty then draw() end
        local e = table.pack(event.pull(0.25))
        local name = e[1]
        if name == "interrupted" then
            running = false
        elseif name == "key_down" then
            onKey(e[3], e[4])
        elseif name == "touch" then
            onTouch(e[3], e[4])
        elseif name == "scroll" then
            if view == "log" then logPage = logPage - (e[5] or 0) else sel = sel - (e[5] or 0) end
            dirty = true
        elseif name == "component_added" or name == "component_removed" then
            if e[3] == "stargate" then
                gate = Gate.find()
                style = Styles.forGate(gate)
                applyPalette(style.palette)
                setMessage(gate and "Stargate connected" or "Stargate disconnected", gate and colors.lime or colors.red)
                full = true
            end
        elseif name == "gatedial_redraw" then
            dirty = true
        end
        if #queue > 0 and gate then
            local pending = queue
            queue = {}
            for _, ge in ipairs(pending) do onGateEvent(gate:event(ge)) end
        end
        local now = computer.uptime()
        if gate and now >= nextPoll then
            gate:poll()
            nextPoll = now + CONFIG.pollInterval
            dirty = true
        end
        -- keep the gate moving on screen while something happens
        if gate and gate.state ~= "IDLE" and now - pictureAt > 0.5 then dirty = true end
        if CONFIG.alarm and gate and gate.state == "INCOMING" and not gate.connected and now - alarmBeep > 0.6 then
            alarmBeep = now
            computer.beep(1200, 0.15)
        end
    end
end

local ok, err = pcall(main)
cleanup()
if not ok and err ~= "interrupted" then io.stderr:write(tostring(err) .. "\n") end
print("gatedial " .. VERSION .. " closed.")
