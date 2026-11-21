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
--   A           automatic iris on/off    L       the gate log
--   Q           quit
--
-- Touch works too: tap an address to pick it, tap it again to dial, or use the buttons.
--
-- On a tier 2 or tier 3 screen gatedial shows the console: the address book, the selected
-- address with big Dial, Close and Iris buttons, switches, the GDO (iris codes) and the gate
-- with its chevrons. Set screen = "classic" below for the plain list of gatedial 1.0.
--

local VERSION = "2.0"

--
-- CONFIGURATION
--
local CONFIG = {
    dataFile = "dialer_addresses.db",
    codesFile = "iris_codes.db",
    logFile = "gate_log.db",
    -- "console": panels, big buttons and the gate (needs a tier 2 or tier 3 screen and graphics card)
    -- "classic": the address list of gatedial 1.0
    screen = "console",
    -- the big letters at the top of the console: A-Z, 0-9, - and spaces
    logo = "SGC",
    -- The three switches below can also be flipped on the console, which remembers them
    -- in the address book; these are the values they start with.
    -- open the iris when the gate that dialed in sends a trusted code (see the idc program)
    irisCodes = true,
    -- close the iris when another gate dials in
    autoIris = false,
    -- beep while another gate is dialing in
    alarm = true,
    -- draw the gate (needs a tier 3 screen and graphics card)
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

-- The console is drawn into a buffer first, and only the cells that changed since the last
-- frame go to the screen: a GPU call costs time on OpenComputers, a table write does not.
-- A cell is one string, its character followed by its foreground and background colour as
-- hex digits ("A0f"); a blank cell always has foreground 0, so only its background counts.
-- One table slot per cell keeps the buffers small: memory is tight on OpenComputers.
local UTF8_CHAR = "[\1-\127\194-\244][\128-\191]*"
local HEXDIGITS = "0123456789abcdef"
local HEXOF, COLOROF, BLANK = {}, {}, {}
for i = 0, 15 do
    local h = HEXDIGITS:sub(i + 1, i + 1)
    HEXOF[2 ^ i] = h
    COLOROF[h:byte()] = 2 ^ i
    BLANK[2 ^ i] = " 0" .. h
end
local buffered = false
local back, front = {}, {}

local function bufClear()
    local blank = BLANK[colors.black]
    for y = 1, H do
        local row = back[y]
        if not row then row = {} back[y] = row end
        for x = 1, W do row[x] = blank end
    end
end

-- forget what is on the screen, so the next flush draws every cell
local function bufInvalidate()
    for y = 1, H do front[y] = {} end
end

local function bufText(x, y, s, fg, bg)
    local row = back[y]
    if not row then return end
    local tail, blank = HEXOF[fg] .. HEXOF[bg], BLANK[bg]
    for ch in s:gmatch(UTF8_CHAR) do
        if x >= 1 and x <= W then row[x] = (ch == " ") and blank or (ch .. tail) end
        x = x + 1
    end
end

local function bufFill(x, y, w, h, bg)
    local blank = BLANK[bg]
    for yy = math.max(1, y), math.min(H, y + h - 1) do
        local row = back[yy]
        for xx = math.max(1, x), math.min(W, x + w - 1) do row[xx] = blank end
    end
end

local function flush()
    for y = 1, H do
        local b, f = back[y], front[y]
        local x = 1
        while x <= W do
            local cell = b[x]
            if cell ~= f[x] then
                -- one gpu.set for a run of cells in the same colours, through short unchanged stretches
                local fg, bg = cell:byte(-2), cell:byte(-1)
                local last, n = x, x + 1
                while n <= W and n - last <= 6 do
                    local c = b[n]
                    if c:byte(-1) ~= bg or (c:byte(-2) ~= fg and c:sub(1, -3) ~= " ") then break end
                    if c ~= f[n] then last = n end
                    n = n + 1
                end
                local chars = {}
                for i = x, last do
                    chars[#chars + 1] = b[i]:sub(1, -3)
                    f[i] = b[i]
                end
                setFg(COLOROF[fg])
                setBg(COLOROF[bg])
                gpu.set(x, y, table.concat(chars))
                x = last + 1
            else
                x = x + 1
            end
        end
    end
end

local function text(x, y, s, fg, bg)
    if buffered then bufText(x, y, tostring(s), fg or colors.white, bg or colors.black) return end
    setFg(fg or colors.white)
    setBg(bg or colors.black)
    gpu.set(x, y, s)
end

local function fill(x, y, w, h, bg)
    if w < 1 or h < 1 then return end
    if buffered then bufFill(x, y, w, h, bg or colors.black) return end
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
-- the switches; the console remembers them in the address book's settings
local opts = {
    irisCodes = book:setting("gatedial.irisCodes", CONFIG.irisCodes),
    autoIris = book:setting("gatedial.autoIris", CONFIG.autoIris),
    alarm = book:setting("gatedial.alarm", CONFIG.alarm),
}
-- the last iris code that came in and the last one we sent: { code, result, who }
local gdo = { incoming = nil, outgoing = nil }
local trustedCount = #IDC.load(CONFIG.codesFile)
local maxEnergy = gate and tonumber(gate:call("getMaxEnergyStored")) or nil

local function setMessage(s, c)
    message.text, message.color = s or "", c or colors.lightGray
    dirty = true
end

local OPT_NAMES = { irisCodes = "Iris code check", autoIris = "Automatic iris", alarm = "Alarm" }

local function toggleOpt(key)
    opts[key] = not opts[key]
    book:set("gatedial." .. key, opts[key])
    setMessage(OPT_NAMES[key] .. (opts[key] and " on" or " off"), opts[key] and colors.lime or colors.lightGray)
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

-- 5 x 7 letters for the console's logo, drawn with half blocks
local FONT = {
    A = ".###. #...# #...# ##### #...# #...# #...#", B = "####. #...# #...# ####. #...# #...# ####.",
    C = ".###. #...# #.... #.... #.... #...# .###.", D = "####. #...# #...# #...# #...# #...# ####.",
    E = "##### #.... #.... ####. #.... #.... #####", F = "##### #.... #.... ####. #.... #.... #....",
    G = ".###. #...# #.... #.### #...# #...# .####", H = "#...# #...# #...# ##### #...# #...# #...#",
    I = ".###. ..#.. ..#.. ..#.. ..#.. ..#.. .###.", J = "..### ...#. ...#. ...#. ...#. #..#. .##..",
    K = "#...# #..#. #.#.. ##... #.#.. #..#. #...#", L = "#.... #.... #.... #.... #.... #.... #####",
    M = "#...# ##.## #.#.# #.#.# #...# #...# #...#", N = "#...# #...# ##..# #.#.# #..## #...# #...#",
    O = ".###. #...# #...# #...# #...# #...# .###.", P = "####. #...# #...# ####. #.... #.... #....",
    Q = ".###. #...# #...# #...# #.#.# #..#. .##.#", R = "####. #...# #...# ####. #.#.. #..#. #...#",
    S = ".#### #.... #.... .###. ....# ....# ####.", T = "##### ..#.. ..#.. ..#.. ..#.. ..#.. ..#..",
    U = "#...# #...# #...# #...# #...# #...# .###.", V = "#...# #...# #...# #...# #...# .#.#. ..#..",
    W = "#...# #...# #...# #.#.# #.#.# #.#.# .#.#.", X = "#...# #...# .#.#. ..#.. .#.#. #...# #...#",
    Y = "#...# #...# .#.#. ..#.. ..#.. ..#.. ..#..", Z = "##### ....# ...#. ..#.. .#... #.... #####",
    ["0"] = ".###. #...# #..## #.#.# ##..# #...# .###.", ["1"] = "..#.. .##.. ..#.. ..#.. ..#.. ..#.. .###.",
    ["2"] = ".###. #...# ....# ...#. ..#.. .#... #####", ["3"] = "##### ...#. ..#.. ...#. ....# #...# .###.",
    ["4"] = "...#. ..##. .#.#. #..#. ##### ...#. ...#.", ["5"] = "##### #.... ####. ....# ....# #...# .###.",
    ["6"] = "..##. .#... #.... ####. #...# #...# .###.", ["7"] = "##### ....# ...#. ..#.. .#... .#... .#...",
    ["8"] = ".###. #...# #...# .###. #...# #...# .###.", ["9"] = ".###. #...# #...# .#### ....# ...#. .##..",
    ["-"] = "..... ..... ..... ##### ..... ..... .....", [" "] = "..... ..... ..... ..... ..... ..... .....",
}

local function logoWidth(s, scale)
    local n = unicode.len(s)
    if n == 0 then return 0 end
    return (n * 6 - 1) * scale
end

-- the logo as rows of half-block characters, scale = how many screen pixels per letter pixel
local function logoRows(s, scale)
    local w = logoWidth(s, scale)
    local px = {}
    for y = 1, 7 * scale + 1 do px[y] = {} end
    local i = 0
    for ch in s:upper():gmatch(UTF8_CHAR) do
        local g = FONT[ch] or FONT[" "]
        local r = 0
        for row in g:gmatch("%S+") do
            r = r + 1
            for k = 1, 5 do
                if row:sub(k, k) == "#" then
                    for dy = 1, scale do
                        for dx = 1, scale do px[(r - 1) * scale + dy][i * 6 * scale + (k - 1) * scale + dx] = true end
                    end
                end
            end
        end
        i = i + 1
    end
    local out = {}
    for row = 1, math.ceil(7 * scale / 2) do
        local top, bottom, line = px[2 * row - 1], px[2 * row], {}
        for x = 1, w do
            local t, b = top[x], bottom[x]
            line[x] = (t and b) and "\226\150\136" or (t and "\226\150\128" or (b and "\226\150\132" or " "))
        end
        out[row] = table.concat(line)
    end
    return out
end

-- The console: three columns under a header
--   header   logo | gate type and local address | state, iris and energy
--   main     address book | selected address, buttons, switches, GDO | the gate and its chevrons
--   footer   message line and keys
local function layoutConsole()
    L.mode = "console"
    L.picture = CONFIG.gatePicture and W >= 120 and H >= 36
    L.big = H >= 40 and W >= 120
    -- the logo: as large as fits the first column
    L.logo = tostring(CONFIG.logo or "")
    local room = L.picture and math.floor(W * 0.25) or math.floor((W - 24) / 2)
    L.logoScale = 0
    for _, scale in ipairs(L.big and { 2, 1 } or { 1 }) do
        if L.logoScale == 0 and logoWidth(L.logo, scale) <= room then L.logoScale = scale end
    end
    L.logoRows = L.logoScale > 0 and logoRows(L.logo, L.logoScale) or nil
    L.logoW = L.logoScale > 0 and logoWidth(L.logo, L.logoScale) or unicode.len(L.logo)
    L.headY = 2
    L.headH = (L.big and L.logoScale == 2) and 7 or (L.big and 6 or 4)
    L.sepY = L.headY + L.headH
    L.mainY = L.sepY + 1
    L.footY = H - 2
    L.messageY = H - 1
    L.hintY = H
    L.mainH = L.footY - L.mainY
    -- columns, with a dashed line between them
    L.aX = 3
    if L.picture then
        L.aW = math.floor(W * 0.25)
        L.bW = math.floor(W * 0.21)
    else
        local free = W - 4 - 14 - 6
        L.aW = math.floor(free / 2)
        L.bW = free - L.aW
    end
    L.sep1 = L.aX + L.aW + 1
    L.bX = L.sep1 + 2
    L.sep2 = L.bX + L.bW + 1
    L.cX = L.sep2 + 2
    L.cW = W - 1 - L.cX
    -- the address book box and the buttons under it
    L.bookButtonRows = L.big and 2 or 1
    L.listH = L.mainH - 3 - (L.big and 4 or 2)
    L.logRows = L.mainH - 5
    -- the gate and its chevrons
    L.chevW = L.picture and 19 or L.cW
    if L.picture then
        L.picX, L.picY = L.cX, L.mainY + 1
        L.picW, L.picH = L.cW - L.chevW - 1, L.mainH - 4
        canvas = Pixels.newHalf(L.picW, L.picH, colors.black)
        ring = Ring.new(canvas, canvas.w / 2, canvas.h / 2 + 0.5, math.min(canvas.w, canvas.h) / 2 / 1.1)
    end
    buffered = true
    bufClear()
    bufInvalidate()
end

local function layout()
    if CONFIG.screen ~= "classic" and paletteColors and W >= 80 and H >= 25 then return layoutConsole() end
    L.mode = "classic"
    buffered = false
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
    -- a call from another galaxy locks 8 or 9 chevrons
    local total = math.max(7, #syms, (not gate.outgoing and gate.incomingSize) or 0)
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
    if gate.mod == "lanteacraft" then
        -- LanteaCraft codes go from a traveller's GDO, not from a computer
        setMessage("Wormhole established to " .. entry.name .. " - send code " .. entry.idc .. " with your GDO", colors.lightBlue)
        return
    end
    local ok, why = gate:sendMessage(IDC.message(entry.idc))
    gdo.outgoing = { code = entry.idc, result = ok and "sent" or "not sent", who = entry.name }
    if ok then setMessage("Wormhole established to " .. entry.name .. " - iris code sent", colors.lightBlue)
    else setMessage("Wormhole established to " .. entry.name .. " - could not send the iris code: " .. tostring(why), colors.orange) end
end

local function onCode(code, info)
    if not opts.irisCodes or gate.outgoing then return end
    if info and info.gateAccepted then
        -- LanteaCraft: the gate checked the code against its own GDO code and moves the iris itself
        local what = info.action == "close" and " - it closes the iris" or " - it opens the iris"
        setMessage("Iris code " .. code .. " accepted by the gate" .. what, colors.lime)
        gdo.incoming = { code = code, result = "accepted", who = "by the gate" }
        logCall({ kind = "code", text = code .. " accepted by the gate" })
        return
    end
    local codes = IDC.load(CONFIG.codesFile)
    trustedCount = #codes
    local trusted = IDC.check(codes, code)
    gdo.incoming = { code = code, result = trusted and "accepted" or "rejected", who = trusted and trusted.name ~= "" and trusted.name or nil }
    if trusted then
        local who = trusted.name ~= "" and trusted.name or ("code " .. code)
        local opening = gate.hasIris and (gate.iris or 0) > 0 and not (info and info.action == "close")
        if opening then
            local ok, why = gate:openIris()
            if ok == false then
                setMessage("Iris code " .. code .. " accepted: " .. who .. " - but the iris won't open: " .. tostring(why), colors.orange)
                logCall({ kind = "code", text = code .. " accepted (" .. who .. ")" })
                return
            end
        end
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
        if opts.autoIris and gate.hasIris and (gate.iris or 0) < 100 then gate:closeIris() end
        setMessage("Unscheduled offworld activation", colors.red)
    elseif ty == "incoming" then
        local who = info.address and book:describe(info.address)
        setMessage("Incoming wormhole" .. (who and (" from " .. who) or ""), colors.red)
        if opts.autoIris and gate.hasIris and (gate.iris or 0) < 100 then gate:closeIris() end
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
            if info.error then setMessage("Gate reset" .. (info.reason and (": " .. info.reason) or ""), colors.red)
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
        if kind == "code" then onCode(value, info)
        elseif kind == "accepted" then
            setMessage("Iris code accepted" .. (value and (" as " .. value) or "") .. " - the way is open", colors.lime)
            if gdo.outgoing then gdo.outgoing.result = "accepted" end
            logCall({ kind = "code", text = "our code accepted" })
        elseif kind == "rejected" then
            if gdo.outgoing then gdo.outgoing.result = "rejected" end
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
        if buffered then return bufText(x, y, s, 2 ^ fgi, 2 ^ bgi) end
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

---------------------------------------------------------------------------
-- The console
---------------------------------------------------------------------------

local editEntry, deleteEntry -- below, with the other typed input

local DASH_H, DASH_V = "\226\149\140", "\226\149\142" -- U+254C, U+254E
local BOX = { tl = "\226\148\140", tr = "\226\148\144", bl = "\226\148\148", br = "\226\148\152", h = "\226\148\128", v = "\226\148\130" }
local UP, DOWN = "\226\150\178", "\226\150\188" -- U+25B2, U+25BC

local function centered(s, w)
    s = tostring(s)
    local n = unicode.len(s)
    if n >= w then return unicode.sub(s, 1, w) end
    local l = math.floor((w - n) / 2)
    return (" "):rep(l) .. s .. (" "):rep(w - n - l)
end

local function rightAligned(s, w)
    s = tostring(s)
    local n = unicode.len(s)
    if n >= w then return unicode.sub(s, 1, w) end
    return (" "):rep(w - n) .. s
end

local function label(x, y, s, w)
    text(x, y, w and fit(s, w) or s, colors.lightGray, colors.black)
end

-- a filled block with its label in the middle; tapping it calls fn
local function block(x, y, w, h, s, fg, bg, fn)
    if w < 1 then return end
    fill(x, y, w, h, bg)
    text(x, y + math.floor((h - 1) / 2), centered(s, w), fg, bg)
    if fn then hit(x, y, x + w - 1, y + h - 1, fn) end
end

-- buttons side by side, sharing the width w: list of { label, fg, bg, fn }
local function buttonRow(x, y, w, h, list)
    local n = #list
    local bw = math.floor((w - (n - 1)) / n)
    for i, b in ipairs(list) do
        local bx = x + (i - 1) * (bw + 1)
        block(bx, y, i == n and (x + w - bx) or bw, h, b[1], b[2], b[3], b[4])
    end
end

local function box(x, y, w, h, color)
    text(x, y, BOX.tl .. BOX.h:rep(w - 2) .. BOX.tr, color)
    for yy = y + 1, y + h - 2 do
        text(x, yy, BOX.v, color)
        text(x + w - 1, yy, BOX.v, color)
    end
    text(x, y + h - 1, BOX.bl .. BOX.h:rep(w - 2) .. BOX.br, color)
end

-- words (or JSG symbol names) on lines of at most w characters
local function wrap(address, w, maxLines)
    local words = {}
    if A.kind(address) == "names" then
        local names = A.strip(address)
        for i, s in ipairs(names) do words[i] = tostring(s) .. (i < #names and "," or "") end
    else
        for word in tostring(A.format(address)):gmatch("%S+") do words[#words + 1] = word end
    end
    local lines, line = {}, ""
    for _, word in ipairs(words) do
        if line == "" then line = word
        elseif unicode.len(line) + 1 + unicode.len(word) <= w then line = line .. " " .. word
        else lines[#lines + 1] = line line = word end
    end
    if line ~= "" then lines[#lines + 1] = line end
    if maxLines and #lines > maxLines then
        local last = lines[maxLines]
        for i = maxLines + 1, #lines do last = last .. " " .. lines[i] end
        lines = { table.unpack(lines, 1, maxLines) }
        lines[maxLines] = unicode.len(last) > w and (unicode.sub(last, 1, w - 3) .. "...") or last
    end
    return lines
end

-- JSG's symbol names shortened: Aqu-Cet-Gem-Leo-Sco-Ori
local function shortAddress(address)
    if A.kind(address) ~= "names" then return A.format(address) end
    local short = {}
    for i, s in ipairs(A.strip(address)) do short[i] = unicode.sub(tostring(s), 1, 3) end
    return table.concat(short, "-")
end

-- an address on at most maxLines lines of w characters, shortened when it does not fit
local function addressLines(address, w, maxLines)
    local lines = wrap(address, w)
    if #lines <= maxLines then return lines end
    return { shortAddress(address) }
end

-- badge texts too long for a narrow badge
local SHORT_LABEL = { ["INCOMING WORMHOLE"] = "INCOMING", ["WORMHOLE OPEN"] = "OPEN" }
local function badgeText(s, w)
    if unicode.len(s) > w and SHORT_LABEL[s] then return SHORT_LABEL[s] end
    return s
end

local function energyText(e, unit)
    if type(e) ~= "number" then return "-" end
    local s
    if e >= 1e9 then s = string.format("%.2fG", e / 1e9)
    elseif e >= 1e6 then s = string.format("%.2fM", e / 1e6)
    elseif e >= 1e4 then s = string.format("%.1fk", e / 1e3)
    else s = string.format("%.0f", e) end
    return s .. " " .. (unit or "")
end

local function mmss(secs)
    secs = math.floor(secs or 0)
    return string.format("%02d:%02d", math.floor(secs / 60), secs % 60)
end

local function flashOn() return math.floor(computer.uptime() * 2) % 2 == 0 end

-- what the gate is doing: badge text, text colour, badge colour
local function stateBadge()
    if not gate then return "NO GATE", colors.lightGray, colors.gray end
    local st = gate.state
    if gate.connected then
        if gate.outgoing then return "WORMHOLE OPEN", colors.black, colors.lightBlue end
        return "INCOMING WORMHOLE", colors.white, colors.red
    end
    if dial.active or st == "DIALING" then return "DIALING", colors.black, colors.orange end
    if st == "INCOMING" then return "INCOMING", colors.white, flashOn() and colors.red or colors.magenta end
    if st == "CLOSING" then return "CLOSING", colors.black, colors.lightGray end
    if st == "OFFLINE" then return "OFFLINE", colors.lightGray, colors.gray end
    return "IDLE", colors.black, colors.lightGray
end

local function irisBadge()
    if not (gate and gate.hasIris) then return "NO IRIS", colors.lightGray, colors.gray end
    local i = gate.iris
    if i == nil then return "UNKNOWN", colors.black, colors.lightGray end
    if i >= 100 then return "CLOSED", colors.white, colors.red end
    if i <= 0 then return "OPEN", colors.black, colors.lime end
    return "MOVING", colors.black, colors.yellow
end

-- one line about the wormhole, and its colour
local function gateLine()
    if not gate then return "No stargate: cable the computer to the gate", colors.red end
    if gate.connected then
        local who = gate.remote and book:describe(gate.remote)
        local secs = mmss(gate:openSeconds())
        if gate.outgoing then return "Wormhole open" .. (who and (" to " .. who) or "") .. "  " .. secs, colors.lightBlue end
        return "Incoming wormhole" .. (who and (" from " .. who) or "") .. "  " .. secs, colors.red
    end
    if dial.active then
        local _, total, lit = chevronPlan()
        return "Dialing " .. (dial.entry and dial.entry.name or A.format(dial.address)) .. "  chevron " .. lit .. " of " .. total, colors.orange
    end
    local st = gate.state
    if st == "INCOMING" then return "Unscheduled offworld activation", colors.red end
    if st == "DIALING" then return "Dialing (DHD)", colors.orange end
    if st == "CLOSING" then return "Wormhole closing", colors.lightGray end
    if st == "OFFLINE" then return "The gate is not complete", colors.gray end
    return "Gate idle", colors.lightGray
end

local function drawFrame()
    local c = colors.gray
    text(1, 1, DASH_H:rep(W), c)
    text(1, L.sepY, DASH_H:rep(W), c)
    text(1, L.footY, DASH_H:rep(W), c)
    for y = 2, L.footY - 1 do
        if y ~= L.sepY then
            text(1, y, DASH_V, c)
            text(W, y, DASH_V, c)
            if not (view == "log" and y > L.sepY) then text(L.sep1, y, DASH_V, c) end
            text(L.sep2, y, DASH_V, c)
        end
    end
end

local function drawConsoleHeader()
    local y = L.headY
    -- logo
    if L.logoRows then
        for i, row in ipairs(L.logoRows) do text(L.aX, y + i - 1, row, colors.orange) end
        local lx = L.aX + L.logoW + 2
        if L.sep1 - lx >= 10 then
            text(lx, y, fit("gatedial", L.sep1 - lx - 1), colors.lightGray)
            text(lx, y + 1, fit("v" .. VERSION, L.sep1 - lx - 1), colors.gray)
        end
    else
        text(L.aX, y, fit(L.logo, L.aW), colors.orange)
        text(L.aX, y + 1, fit("gatedial " .. VERSION, L.aW), colors.lightGray)
    end
    -- the gate
    local x, w = L.bX, L.bW
    if not gate then
        text(x, y, fit("NO STARGATE", w), colors.red)
        text(x, y + 1, fit("Cable the computer to the", w), colors.lightGray)
        text(x, y + 2, fit("gate's base or interface", w), colors.lightGray)
    else
        local addr = gate.localAddress
        if L.headH >= 6 then
            label(x, y, "STARGATE", w)
            text(x, y + 1, fit(gate.typeName, w), colors.white)
            text(x, y + 2, fit(gate.interfaceName, w), colors.gray)
            label(x, y + L.headH - 3, "LOCAL ADDRESS", w)
            local lines = addr and addressLines(addr, w, 2) or { "unknown" }
            for i, s in ipairs(lines) do text(x, y + L.headH - 3 + i, fit(s, w), colors.orange) end
        else
            text(x, y, fit(gate.typeName .. " stargate", w), colors.white)
            label(x, y + 1, "LOCAL ADDRESS", w)
            local lines = addr and addressLines(addr, w, 2) or { "unknown" }
            for i, s in ipairs(lines) do text(x, y + 1 + i, fit(s, w), colors.orange) end
        end
    end
    -- state, iris and energy
    x, w = L.cX, L.cW
    local st, stFg, stBg = stateBadge()
    local ir, irFg, irBg = irisBadge()
    local energy = gate and energyText(gate.energy, gate.energyUnit) or "-"
    if L.headH >= 6 then
        local sw = math.floor(w * 0.42)
        local iw = math.floor(w * 0.2)
        local ex = x + sw + iw + 4
        local ew = x + w - ex
        label(x, y, "GATE STATUS", sw)
        block(x, y + 1, sw, 3, badgeText(st, sw), stFg, stBg)
        label(x + sw + 2, y, "IRIS", iw)
        block(x + sw + 2, y + 1, iw, 3, ir, irFg, irBg, gate and gate.hasIris and toggleIris or nil)
        label(ex, y, "ENERGY", ew)
        text(ex, y + 2, fit(energy, ew), colors.white)
        if maxEnergy and maxEnergy > 0 and gate and type(gate.energy) == "number" then
            local filled = math.floor(math.max(0, math.min(1, gate.energy / maxEnergy)) * ew + 0.5)
            fill(ex, y + 3, filled, 1, colors.orange)
            fill(ex + filled, y + 3, ew - filled, 1, colors.gray)
        end
        -- the gate on the other side
        local remote = dial.active and dial.address or (gate and gate.state ~= "IDLE" and gate.remote) or nil
        local who = remote and book:describe(remote)
        label(x, y + 5, "REMOTE", 8)
        if remote then
            text(x + 8, y + 5, fit(who, w - 8), colors.white)
            local used = 8 + unicode.len(who) + 2
            if who ~= A.format(remote) and used < w then text(x + used, y + 5, fit(shortAddress(remote), w - used), colors.orange) end
        else
            text(x + 8, y + 5, fit(gate and gate.state ~= "IDLE" and "unknown gate" or "-", w - 8), colors.gray)
        end
    else
        block(x, y, w, 1, badgeText(st, w), stFg, stBg)
        block(x, y + 1, w, 1, ir == "NO IRIS" and ir or ("IRIS " .. ir), irFg, irBg, gate and gate.hasIris and toggleIris or nil)
        text(x, y + 2, fit(energy, w), colors.white)
        if gate and gate.connected then text(x, y + 3, fit("open " .. mmss(gate:openSeconds()), w), colors.lightGray) end
    end
end

local function drawBook()
    local x, y, w = L.aX, L.mainY, L.aW
    local list = entries()
    sel = math.max(1, math.min(sel, math.max(1, #list)))
    if sel <= scroll then scroll = sel - 1 end
    if sel > scroll + L.listH then scroll = sel - L.listH end
    scroll = math.max(0, math.min(scroll, math.max(0, #list - L.listH)))
    label(x, y, "ADDRESS BOOK", w - 6)
    text(x + w - 6, y, rightAligned(tostring(#list), 6), colors.gray)
    box(x, y + 1, w, L.listH + 2, colors.gray)
    for row = 1, L.listH do
        local i = scroll + row
        local e = list[i]
        local yy = y + 1 + row
        if e then
            local selected = i == sel
            local bg = selected and colors.blue or colors.black
            local fg = selected and colors.white or (e.last == "fail" and colors.red or (e.address and colors.white or colors.gray))
            local tag = e.idc and "IDC " or ""
            text(x + 1, yy, fit(" " .. e.name, w - 2 - unicode.len(tag)), fg, bg)
            if tag ~= "" then text(x + w - 1 - unicode.len(tag), yy, tag, selected and colors.lightBlue or colors.cyan, bg) end
            hit(x + 1, yy, x + w - 2, yy, function()
                local now = computer.uptime()
                if lastTap.row == i and now - lastTap.t < 1.5 then startDial(e) end
                sel, lastTap.row, lastTap.t = i, i, now
                dirty = true
            end)
        end
    end
    if #list == 0 then text(x + 2, y + 2, fit("Empty - N adds an address", w - 4), colors.lightGray) end
    if scroll > 0 then text(x + w - 1, y + 2, UP, colors.orange) end
    if scroll + L.listH < #list then text(x + w - 1, y + 1 + L.listH, DOWN, colors.orange) end
    hit(x + w - 1, y + 2, x + w - 1, y + 2, function() sel = math.max(1, sel - L.listH) end)
    hit(x + w - 1, y + 1 + L.listH, x + w - 1, y + 1 + L.listH, function() sel = sel + L.listH end)
    local blue, white = colors.blue, colors.white
    local function new() editEntry(nil) end
    local function edit() editEntry(list[sel]) end
    local function delete() deleteEntry(list[sel]) end
    local function openLog() view = "log" full = true end
    local by = L.mainY + L.mainH - 1
    if L.big then
        buttonRow(x, by - 2, w, 1, { { "NEW", white, blue, new }, { "EDIT", white, blue, edit }, { "DELETE", white, blue, delete } })
        buttonRow(x, by, w, 1, { { "LOG", white, blue, openLog }, { "QUIT", colors.lightGray, colors.gray, function() running = false end } })
    else
        buttonRow(x, by, w, 1, { { "NEW", white, blue, new }, { "EDIT", white, blue, edit }, { "DEL", white, blue, delete }, { "LOG", white, blue, openLog } })
    end
end

local function drawConsoleLog()
    local x, y = L.aX, L.mainY
    local w = L.bX + L.bW - x
    local per = L.logRows
    local pages = math.max(1, math.ceil(#log.entries / per))
    logPage = math.max(1, math.min(logPage, pages))
    label(x, y, "GATE LOG", w - 12)
    text(x + w - 12, y, rightAligned("page " .. logPage .. "/" .. pages, 12), colors.gray)
    box(x, y + 1, w, per + 2, colors.gray)
    for row = 1, per do
        local e = log.entries[(logPage - 1) * per + row]
        local yy = y + 1 + row
        if e then
            local when, kind, info = CallLog.describe(e)
            text(x + 2, yy, fit(kind, 6), LOG_COLORS[e.kind] or colors.white)
            text(x + 9, yy, fit(when, 14), colors.lightGray)
            text(x + 24, yy, fit(info, w - 26), colors.white)
        end
    end
    if #log.entries == 0 then text(x + 2, y + 2, "Nothing has gone through the gate yet", colors.lightGray) end
    local blue, white = colors.blue, colors.white
    buttonRow(x, y + L.mainH - 1, w, 1, {
        { "BACK", white, blue, function() view = "list" full = true end },
        { "NEWER", white, blue, function() logPage = logPage - 1 end },
        { "OLDER", white, blue, function() logPage = logPage + 1 end },
    })
end

local function toggleLine(x, y, w, name, key)
    local on = opts[key]
    text(x, y, fit(name, w - 6), colors.white)
    text(x + w - 5, y, on and " ON  " or " OFF ", on and colors.black or colors.lightGray, on and colors.lime or colors.gray)
    hit(x, y, x + w - 1, y, function() toggleOpt(key) end)
end

local GDO_COLORS = { accepted = colors.lime, rejected = colors.red, sent = colors.lightBlue, ["not sent"] = colors.orange }

local function gdoLine(x, y, w, prefix, g)
    if not g then
        text(x, y, fit(prefix .. "  -", w), colors.gray)
        return
    end
    local s = prefix .. "  " .. g.code .. "  " .. g.result .. (g.who and (" (" .. g.who .. ")") or "")
    text(x, y, fit(s, w), GDO_COLORS[g.result] or colors.white)
end

local function drawControls()
    local x, y, w = L.bX, L.mainY, L.bW
    local list = entries()
    local e = list[sel]
    label(x, y, "SELECTED", w - 8)
    if #list > 0 then text(x + w - 8, y, rightAligned(sel .. "/" .. #list, 8), colors.gray) end
    local busy = gate and (gate.state ~= "IDLE" or dial.active)
    local dialLabel, dialFg, dialBg = "DIAL", colors.white, colors.blue
    if dial.active then dialLabel, dialFg, dialBg = "ABORT DIALING", colors.black, colors.orange
    elseif not (gate and e and e.address) or busy then dialFg, dialBg = colors.lightGray, colors.gray end
    local closeFg, closeBg = colors.lightGray, colors.gray
    if gate and gate.state ~= "IDLE" and not dial.active then closeFg, closeBg = colors.white, colors.red end
    local irisLabel, irisFg, irisBg = "NO IRIS", colors.lightGray, colors.gray
    if gate and gate.hasIris then
        irisLabel = (gate.iris or 0) >= 50 and "OPEN IRIS" or "CLOSE IRIS"
        irisFg, irisBg = colors.white, colors.blue
    end
    local function dialIt() if dial.active then closeGate() else startDial(e) end end
    local codeText = e and (e.idc or "none") or ""
    if L.mainH >= 35 then
        label(x, y + 2, "NAME", w)
        block(x, y + 3, w, 1, "", colors.white, colors.gray)
        text(x + 1, y + 3, fit(e and e.name or "-", w - 2), colors.white, colors.gray)
        label(x, y + 5, "ADDRESS", w)
        fill(x, y + 6, w, 3, colors.gray)
        local lines = e and e.address and addressLines(e.address, w - 2, 3) or { e and "no address yet" or "-" }
        for i, s in ipairs(lines) do text(x + 1, y + 5 + i, fit(s, w - 2), e and e.address and colors.orange or colors.lightGray, colors.gray) end
        label(x, y + 10, "IRIS CODE TO SEND", w)
        fill(x, y + 11, w, 1, colors.gray)
        text(x + 1, y + 11, fit(codeText, w - 2), e and e.idc and colors.white or colors.lightGray, colors.gray)
        block(x, y + 13, w, 3, dialLabel, dialFg, dialBg, dialIt)
        block(x, y + 17, w, 3, "CLOSE GATE", closeFg, closeBg, closeGate)
        block(x, y + 21, w, 3, irisLabel, irisFg, irisBg, toggleIris)
        label(x, y + 25, "SWITCHES", w)
        toggleLine(x, y + 26, w, "Automatic iris", "autoIris")
        toggleLine(x, y + 27, w, "Iris code check", "irisCodes")
        toggleLine(x, y + 28, w, "Alarm", "alarm")
        label(x, y + 30, "GDO", w - 10)
        text(x + w - 10, y + 30, rightAligned(trustedCount .. " trusted", 10), colors.gray)
        gdoLine(x, y + 31, w, "IN ", gdo.incoming)
        gdoLine(x, y + 32, w, "OUT", gdo.outgoing)
        text(x, y + 33, fit("idc add <code> <name>", w), colors.gray)
    else
        fill(x, y + 1, w, 3, colors.gray)
        text(x + 1, y + 1, fit(e and e.name or "-", w - 2), colors.white, colors.gray)
        text(x + 1, y + 2, fit(e and e.address and shortAddress(e.address) or (e and "no address yet" or "-"), w - 2), e and e.address and colors.orange or colors.lightGray, colors.gray)
        text(x + 1, y + 3, fit("Code " .. codeText, w - 2), colors.lightGray, colors.gray)
        block(x, y + 5, w, 1, dialLabel, dialFg, dialBg, dialIt)
        buttonRow(x, y + 7, w, 1, { { "CLOSE", closeFg, closeBg, closeGate }, { irisLabel, irisFg, irisBg, toggleIris } })
        toggleLine(x, y + 9, w, "Auto iris", "autoIris")
        toggleLine(x, y + 10, w, "Code check", "irisCodes")
        toggleLine(x, y + 11, w, "Alarm", "alarm")
        label(x, y + 13, "GDO  " .. trustedCount .. " trusted", w)
        gdoLine(x, y + 14, w, "IN ", gdo.incoming)
        gdoLine(x, y + 15, w, "OUT", gdo.outgoing)
    end
end

-- the chevrons, top to bottom: a box each, lit as it locks, with its symbol
local function drawChevrons()
    local syms, total, lit = chevronPlan()
    local x, w = L.cX + L.cW - L.chevW, L.chevW
    if L.picture then
        label(x, L.mainY, "CHEVRONS", w)
        local top, rows = L.picY, L.picH
        local gap = total > 1 and math.min(2, math.floor((rows - total * 3) / (total - 1))) or 0
        gap = math.max(0, gap)
        local used = total * 3 + (total - 1) * gap
        local y = top + math.max(0, math.floor((rows - used) / 2))
        for i = 1, total do
            local on = i <= lit
            local c = on and (i == total and colors.red or colors.orange) or colors.gray
            local name = syms[i] ~= nil and (A.isOriginName(syms[i]) and "Origin" or (syms[i] == 0 and "PoO" or tostring(syms[i]))) or ""
            if on then
                fill(x, y, 5, 3, c)
                text(x, y + 1, centered(tostring(i), 5), colors.black, c)
            else
                box(x, y, 5, 3, c)
                text(x + 1, y + 1, centered(tostring(i), 3), colors.gray)
            end
            text(x + 6, y + 1, fit(name, w - 6), on and colors.white or colors.gray)
            y = y + 3 + gap
        end
    else
        label(L.cX, L.mainY, "CHEVRONS", L.cW)
        for i = 1, total do
            local on = i <= lit
            local c = on and (i == total and colors.red or colors.orange) or colors.gray
            local y = L.mainY + 1 + i
            text(L.cX, y, on and "\226\150\160" or "\226\150\161", c) -- U+25A0, U+25A1
            text(L.cX + 2, y, fit(i .. " " .. (syms[i] ~= nil and shortSymbol(syms[i]) or ""), L.cW - 2), on and colors.white or colors.gray)
        end
        local line, c = gateLine()
        local lines = {}
        for word in line:gmatch("%S+") do
            if #lines == 0 or unicode.len(lines[#lines]) + 1 + unicode.len(word) > L.cW then lines[#lines + 1] = word
            else lines[#lines] = lines[#lines] .. " " .. word end
        end
        for i = 1, math.min(#lines, L.mainH - total - 3) do
            text(L.cX, L.mainY + total + 2 + i, fit(lines[i], L.cW), c)
        end
    end
end

local function drawGatePanel()
    if L.picture then
        label(L.cX, L.mainY, gate and (gate.typeName:upper() .. " STARGATE") or "STARGATE", L.picW)
        if gate then drawPicture()
        else text(L.cX + 2, L.picY + math.floor(L.picH / 2), fit("No stargate connected", L.picW - 4), colors.red) end
        local line, c = gateLine()
        local y = L.mainY + L.mainH - 2
        text(L.cX, y, fit(line, L.cW), c)
        -- the chevrons as a bar
        local _, total, lit = chevronPlan()
        local bw = L.cW - 8
        local filled = total > 0 and math.floor(bw * lit / total + 0.5) or 0
        fill(L.cX, y + 1, filled, 1, gate and gate.connected and colors.lightBlue or colors.orange)
        fill(L.cX + filled, y + 1, bw - filled, 1, colors.gray)
        text(L.cX + bw + 1, y + 1, fit(lit .. "/" .. total, 7), colors.lightGray)
    end
    drawChevrons()
end

local function drawFooter()
    text(3, L.messageY, fit(message.text, W - 4), message.color)
    local hints = "Enter dial  X close  I iris  A auto iris  N/E/D new/edit/delete  L log  Q quit"
    if W < 120 then hints = "Enter dial  X close  I iris  A auto iris  L log  Q quit" end
    local ver = "gatedial " .. VERSION
    text(3, L.hintY, fit(hints, W - 6 - unicode.len(ver)), colors.gray)
    text(W - 1 - unicode.len(ver), L.hintY, ver, colors.gray)
end

local function drawConsole()
    drawFrame()
    drawConsoleHeader()
    if view == "log" then drawConsoleLog()
    else
        drawBook()
        drawControls()
    end
    drawGatePanel()
    drawFooter()
end

local function draw()
    hits = {}
    if L.mode == "console" then
        if full then
            bufInvalidate()
            full = false
        end
        bufClear()
        -- the picture is painted into the buffer every frame; the flush sends what changed
        if canvas then canvas:invalidate() end
        drawConsole()
        flush()
        pictureAt = computer.uptime()
        dirty = false
        return
    end
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
    if buffered then flush() end
    term.setCursor(4 + unicode.len(label), L.messageY)
    setFg(colors.white)
    setBg(colors.black)
    local line = term.read({ current }, false)
    -- term.read drew on the screen itself
    curFg, curBg = nil, nil
    if buffered then bufInvalidate() end
    if not line then return nil end
    line = line:gsub("[\r\n]+$", "")
    if line == "" and current then return current end
    if line == "-" then return "" end
    return line
end

function editEntry(entry)
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

function deleteEntry(entry)
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
        -- the gate keys work here too: the log is often open when a wormhole comes in
        elseif code == k.x then closeGate()
        elseif code == k.i then toggleIris()
        elseif code == k.a then toggleOpt("autoIris")
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
    elseif code == k.a then toggleOpt("autoIris")
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
                maxEnergy = gate and tonumber(gate:call("getMaxEnergyStored")) or nil
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
        if opts.alarm and gate and gate.state == "INCOMING" and not gate.connected and now - alarmBeep > 0.6 then
            alarmBeep = now
            computer.beep(1200, 0.15)
        end
    end
end

local ok, err = pcall(main)
cleanup()
if not ok and err ~= "interrupted" then io.stderr:write(tostring(err) .. "\n") end
print("gatedial " .. VERSION .. " closed.")
