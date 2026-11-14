--
--   Gate Network Hub
--   A touch screen of destination cards, each with its own portal colour (CC: Tweaked)
--
--   Group your gates into tabs (Milky Way, Pegasus, Crossover...), give every
--   destination a colour, and dial by tapping its card. Destinations you have
--   not found an address for yet can be kept as planned cards.
--
--   Works with Stargate Journey (crystal or advanced crystal interface; the
--   basic interface works for Milky Way gates), SGCraft, Lantea: Stargates
--   and Just Stargate Mod (1.20.1).
--
--   Usage:
--     hub              first advanced monitor, or this screen if there is none
--     hub <monitor>    that monitor
--     hub term         this screen
--     hub chart        add the planned destinations from the crossover network chart
--

local VERSION = "1.0"

--
-- CONFIGURATION
--
local CONFIG = {
    -- address book shared with the Personal Dialer and the Gate Room
    dataFile = "dialer_addresses.db",
    -- peripheral name of the gate interface, nil = first one found
    interfaceName = nil,
    -- monitor text scale
    textScale = 0.5,
    -- width of a destination card in characters (cards stretch to fill the row)
    cardWidth = 18,
    -- dialing speed
    symbolDelay = 0.5,
    chevronDelay = 0.4,
    stepTimeout = 60,
    connectTimeout = 10,
    fastDial = false,
    pollInterval = 1,
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

-- planned destinations from the "All gates, one network" chart (no addresses yet)
local CHART = {
    { name = "SGC",                 note = "Chevron 7, the central hub", group = "Home",      color = "blue" },
    { name = "Home Base",           note = "Family & real life",         group = "Home",      color = "lime" },
    { name = "Protected Spawn",     note = "Iron walls, safe zone",      group = "Home",      color = "lightGray" },
    { name = "The Legacy Gate",     note = "Original series, Earth",     group = "Stargate",  color = "blue" },
    { name = "The Hero Gate",       note = "SG-1, Earth",                group = "Stargate",  color = "blue" },
    { name = "The Atlantis Gate",   note = "Atlantis, Pegasus",          group = "Stargate",  color = "cyan" },
    { name = "The Destiny Gate",    note = "Universe",                   group = "Stargate",  color = "blue" },
    { name = "The Infinity Gate",   note = "Stargate Infinity",          group = "Stargate",  color = "lightBlue" },
    { name = "The Continuum Gate",  note = "Stargate Continuum",         group = "Stargate",  color = "blue" },
    { name = "The Origin Gate",     note = "Stargate Origins, 1939",     group = "Stargate",  color = "brown" },
    { name = "The Ark Gate",        note = "The Ark of Truth",           group = "Stargate",  color = "orange" },
    { name = "The Movie Gate",      note = "Stargate (1994)",            group = "Stargate",  color = "blue" },
    { name = "The Tollan Gate",     note = "Tollana",                    group = "Stargate",  color = "white" },
    { name = "The Necromonger Gate", note = "Riddick universe",          group = "Crossover", color = "red" },
    { name = "The Republic Gate",   note = "Star Wars",                  group = "Crossover", color = "red" },
    { name = "The Federation Gate", note = "Star Trek",                  group = "Crossover", color = "blue" },
    { name = "The Babylon 5 Gate",  note = "Babylon 5",                  group = "Crossover", color = "green" },
    { name = "The Morphin Gate",    note = "Power Rangers",              group = "Crossover", color = "yellow" },
    { name = "The Aperture Gate",   note = "Portal",                     group = "Crossover", color = "orange" },
    { name = "The Black Mesa Gate", note = "Half-Life",                  group = "Crossover", color = "red" },
    { name = "The Avengers Gate",   note = "Avengers",                   group = "Crossover", color = "blue" },
    { name = "The Watchtower Gate", note = "Justice League",             group = "Crossover", color = "lightBlue" },
    { name = "The Titans Gate",     note = "Teen Titans",                group = "Crossover", color = "purple" },
    { name = "The Voltron Gate",    note = "Voltron",                    group = "Crossover", color = "blue" },
    { name = "The Omnitrix Gate",   note = "Ben 10",                     group = "Crossover", color = "lime" },
    { name = "The Digital Gate",    note = "Pokemon / Digimon",          group = "Crossover", color = "cyan" },
    { name = "The Magic Gate",      note = "Disney / family",            group = "Crossover", color = "pink" },
    { name = "The Block Gate",      note = "Minecraft",                  group = "Crossover", color = "green" },
    { name = "The LEGO Gate",       note = "LEGO world",                 group = "Crossover", color = "yellow" },
    { name = "The Nexus Gate",      note = "Destiny Nexus, the multiverse", group = "Crossover", color = "magenta" },
}

local COLOR_CHOICES = { "blue", "lightBlue", "cyan", "green", "lime", "yellow", "orange", "red",
                        "magenta", "pink", "purple", "brown", "white", "lightGray" }

---------------------------------------------------------------------------
-- "hub chart": add the planned destinations and exit
---------------------------------------------------------------------------

if args[1] == "chart" then
    local book = Book.open(CONFIG.dataFile)
    local have, added = {}, 0
    for _, e in ipairs(book.entries) do have[e.name:lower()] = true end
    for _, c in ipairs(CHART) do
        if not have[c.name:lower()] then
            book.entries[#book.entries + 1] = Book.clean(c)
            added = added + 1
        end
    end
    book:save()
    print("Added " .. added .. " planned destinations to " .. CONFIG.dataFile .. ".")
    print("Tap EDIT on the hub, then a card, to give it an address.")
    return
end

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
        if not monitor.isColor() then error("The hub needs an advanced monitor", 0) end
        monitorName = peripheral.getName(monitor)
        monitor.setTextScale(CONFIG.textScale)
    end
end
local target = monitor or native
local ui = UI.new(target)
local W, H, L

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------

local book = Book.open(CONFIG.dataFile)
local gate = Gate.find(CONFIG.interfaceName)
local tab = book:setting("hubTab", "All")
local page = 1
local selected = nil     -- entry
local editMode = false
local editor = nil       -- open editor dialog
local dial = { active = false, abort = false, entry = nil, address = nil, endedAt = -10, failed = false }
local message = { text = "", color = colors.lightGray }
local running = true

local function setMessage(text, color)
    message.text = text or ""
    message.color = color or colors.lightGray
end

local function visibleEntries()
    local out = {}
    -- entries tied to another gate of the base are left out
    for _, e in ipairs(book:visible(gate and gate.localAddress)) do
        if tab == "All" or (e.group or "Other") == tab then out[#out + 1] = e end
    end
    return out
end

local function layout()
    W, H = target.getSize()
    L = { gridX = 2, gridY = 4, gridW = W - 2, gridH = H - 6 }
    local gap = 1
    L.full = math.floor((L.gridH + gap) / 11) >= 2 and W >= 30
    L.ch = L.full and 10 or 3
    L.cols = math.max(1, math.floor((L.gridW + gap) / (CONFIG.cardWidth + gap)))
    L.cw = math.floor((L.gridW + gap) / L.cols) - gap
    L.rows = math.max(1, math.floor((L.gridH + gap) / (L.ch + gap)))
    L.perPage = L.cols * L.rows
    target.setBackgroundColor(colors.black)
    target.clear()
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

local function startDial(entry)
    if not entry then setMessage("Tap a destination first", colors.orange) return end
    if not entry.address then setMessage(entry.name .. " has no address yet - tap EDIT to add it", colors.orange) return end
    if not gate then setMessage("No stargate interface connected", colors.red) return end
    if dial.active then setMessage("Already dialing - CLOSE aborts", colors.orange) return end
    gate:poll()
    if gate.state ~= "IDLE" then setMessage("The gate is busy", colors.red) return end
    local dialable, why = A.dialableBy(entry.address, gate.mod)
    if not dialable then
        setMessage(why, colors.red)
        return
    end
    dial.active, dial.abort, dial.entry, dial.address = true, false, entry, entry.address
    gate.remote, gate.outgoing = entry.address, true
    setMessage("Dialing " .. entry.name .. "...", colors.lightGray)
    os.queueEvent("hub_dial")
end

local function closeGate()
    if dial.active then
        dial.abort = true
        setMessage("Aborting...", colors.orange)
        return
    end
    if not gate then return end
    gate:poll()
    if gate.state == "IDLE" then setMessage("The gate is already idle", colors.gray) return end
    gate:close()
    setMessage("Closing the gate", colors.lightGray)
end

local function toggleIris()
    if not gate then return end
    local ok, err = gate:toggleIris()
    if ok == false then setMessage(tostring(err), colors.orange) end
end

local function openEditor(entry)
    book:reload()
    -- find the same entry again after the reload
    if entry then
        local match
        for _, e in ipairs(book.entries) do
            if e.name == entry.name and (A.same(e.address, entry.address) or (not e.address and not entry.address)) then match = e end
        end
        entry = match
    end
    local addr = ""
    if entry and entry.address then addr = A.format(entry.address)
    elseif not entry and gate and gate.lastIncoming and not book:find(gate.lastIncoming) then addr = A.format(gate.lastIncoming) end
    editor = {
        entry = entry,
        fields = {
            { label = "Name",    value = entry and entry.name or "" },
            { label = "Address", value = addr },
            { label = "Note",    value = entry and entry.note or "" },
            { label = "Group",   value = entry and entry.group or (tab ~= "All" and tab or "") },
        },
        color = entry and entry.color or "blue",
        focus = 1,
        err = nil,
        confirmDelete = false,
    }
end

local function saveEditor()
    local f = editor.fields
    local address, why
    if f[2].value:match("%S") then
        address, why = A.parse(f[2].value)
        if not address then editor.err, editor.focus = why, 2 return end
    end
    local name = f[1].value:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        if not address then editor.err, editor.focus = "Give it a name or an address", 1 return end
        name = A.format(address)
    end
    local item = editor.entry
    local data = { name = name, address = address, note = f[3].value, group = f[4].value, color = editor.color,
                   last = item and A.same(item.address, address) and item.last or nil,
                   -- set in the Personal Dialer, kept as they are
                   idc = item and item.idc, home = item and item.home }
    local clean = Book.clean(data)
    if item then
        for k in pairs(item) do item[k] = nil end
        for k, v in pairs(clean) do item[k] = v end
    else
        book.entries[#book.entries + 1] = clean
        item = clean
    end
    book:save()
    selected = item
    editor = nil
    setMessage("Saved " .. item.name, colors.lime)
end

local function deleteEditor()
    if not editor.entry then editor = nil return end
    if not editor.confirmDelete then
        editor.confirmDelete = true
        return
    end
    for i, e in ipairs(book.entries) do
        if e == editor.entry then table.remove(book.entries, i) break end
    end
    book:save()
    setMessage("Removed " .. editor.entry.name, colors.lightGray)
    if selected == editor.entry then selected = nil end
    editor = nil
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local STATE_BADGE = {
    IDLE = { "IDLE", colors.black, colors.lime },
    DIALING = { "DIALING", colors.black, colors.orange },
    OPEN = { "OPEN", colors.black, colors.lightBlue },
    INCOMING = { "INCOMING", colors.white, colors.red },
    CLOSING = { "CLOSING", colors.black, colors.lightBlue },
    OFFLINE = { "NO GATE", colors.white, colors.gray },
}

local function isActive(e)
    if not gate or not e.address or gate.state == "IDLE" then return false end
    if dial.active then return dial.entry == e end
    return gate.remote ~= nil and A.same(gate.remote, e.address)
end

local function drawCard(e, x, y, w, h)
    local active = isActive(e)
    local sel = (e == selected)
    local col = colors[e.color or "blue"] or colors.blue
    local planned = e.address == nil
    local bg = colors.gray
    ui:fill(x, y, w, h, bg)
    if L.full then
        -- top edge in the portal colour when selected or active
        if sel or active then ui:fill(x, y, w, 1, col) end
        -- the gate icon
        local iw, ih = 10, 5
        local icon = Pixels.new(iw, ih, bg)
        Ring.icon(icon, iw, ih * 1.5, 7, planned and colors.lightGray or colors.white, planned and colors.black or col,
            planned and colors.lightGray or colors.orange)
        icon:draw(target, x + math.floor((w - iw) / 2), y + 1)
        ui:center(x, y + 6, w, e.name, planned and colors.lightGray or colors.white, bg)
        ui:center(x, y + 7, w, e.note ~= "" and e.note or (e.group or ""), colors.lightGray, bg)
        local addr = planned and "no address yet" or A.format(e.address)
        ui:center(x, y + 8, w, addr, planned and colors.lightGray or col == colors.white and colors.lightGray or col, bg)
        if active then
            local status = gate.state == "OPEN" and "\7 CONNECTED" or gate.state == "DIALING" and ("\7 DIALING " .. gate.chevrons) or ("\7 " .. gate.state)
            ui:fill(x, y + 9, w, 1, col)
            ui:center(x, y + 9, w, status, colors.black, col)
        elseif e.last == "ok" then
            ui:center(x, y + 9, w, "last dial ok", colors.lime, bg)
        elseif e.last == "fail" then
            ui:center(x, y + 9, w, "last dial failed", colors.red, bg)
        end
    else
        ui:fill(x, y, 1, h, col)
        if sel or active then ui:fill(x + 1, y, w - 1, 1, col) end
        local nameBg = (sel or active) and col or bg
        ui:write(x + 2, y, fit(e.name, w - 3), (sel or active) and colors.black or (planned and colors.lightGray or colors.white), nameBg)
        ui:write(x + 2, y + 1, fit(e.note ~= "" and e.note or (e.group or ""), w - 3), colors.lightGray, bg)
        local addr = planned and "no address yet" or A.format(e.address)
        if active then addr = "\7 " .. gate.state .. " " .. addr end
        ui:write(x + 2, y + 2, fit(addr, w - 3), planned and colors.lightGray or (col == colors.white and colors.lightGray or col), bg)
    end
    ui:hit(x, y, x + w - 1, y + h - 1, function()
        if editMode then
            openEditor(e)
        elseif selected == e then
            startDial(e)
        else
            selected = e
            setMessage(e.name .. (e.address and " - tap again or DIAL to dial" or " - no address yet"), colors.lightGray)
        end
    end)
end

local function drawTitle()
    ui:fill(1, 1, W, 1, colors.gray)
    ui:write(2, 1, "GATE NETWORK HUB", colors.white, colors.gray)
    local right
    if gate then
        local st = Styles.forGate(gate)
        right = st.name .. " gate " .. (gate.localAddress and A.format(gate.localAddress) or "")
    else
        right = "no interface"
    end
    if 19 + #right + 2 <= W then ui:write(W - #right, 1, right, gate and colors.lightBlue or colors.red, colors.gray) end
end

local function drawTabs()
    ui:fill(1, 2, W, 1, colors.black)
    local groups = book:groups()
    table.insert(groups, 1, "All")
    local x = 2
    for _, g in ipairs(groups) do
        local label = " " .. g .. " "
        if x + #label > W then break end
        local on = g == tab
        ui:button(x, 2, label, on and colors.black or colors.lightGray, on and colors.lightBlue or colors.gray, function()
            tab, page, selected = g, 1, nil
            book.settings.hubTab = g
            book:save()
        end)
        x = x + #label + 1
    end
    if editMode then ui:write(W - 10, 2, " EDIT MODE ", colors.black, colors.yellow) end
end

local function drawGrid()
    ui:fill(1, 3, W, H - 4, colors.black)
    local list = visibleEntries()
    local pages = math.max(1, math.ceil(#list / L.perPage))
    page = math.max(1, math.min(page, pages))
    local first = (page - 1) * L.perPage + 1
    for i = 0, L.perPage - 1 do
        local e = list[first + i]
        if not e then break end
        local col, row = i % L.cols, math.floor(i / L.cols)
        drawCard(e, L.gridX + col * (L.cw + 1), L.gridY + row * (L.ch + 1), L.cw, L.ch)
    end
    if #list == 0 then
        ui:center(1, L.gridY + 2, W, tab == "All" and "No destinations yet - tap + ADD" or "Nothing in " .. tab, colors.lightGray, colors.black)
    end
    return pages
end

local function drawStatus()
    local y = H - 1
    ui:fill(1, y, W, 1, colors.black)
    local st = gate and gate.state or "OFFLINE"
    local badge = STATE_BADGE[st] or STATE_BADGE.IDLE
    local label = " " .. badge[1] .. " "
    ui:write(W - #label, y, label, badge[2], badge[3])
    -- chevrons
    local x = 2
    if gate and st ~= "IDLE" then
        local total = 7
        local addr = (dial.active and dial.address) or gate.remote
        if addr then total = #A.symbols(addr) + (gate.originSymbol ~= nil and 1 or 0) end
        local lit = gate.connected and total or gate.chevrons
        for i = 1, total do
            ui:write(x, y, "\31", i <= lit and colors.orange or colors.gray, colors.black)
            x = x + 1
        end
        x = x + 1
    end
    ui:write(x, y, fit(message.text, W - x - #label - 1), message.color, colors.black)
end

local function drawButtons(pages)
    local y = H
    ui:fill(1, y, W, 1, colors.black)
    local x = 2
    x = ui:button(x, y, " \17 ", colors.white, colors.gray, function() page = page - 1 end)
    local p = " " .. page .. "/" .. pages .. " "
    x = ui:button(x, y, p, colors.lightGray, colors.black)
    x = ui:button(x, y, " \16 ", colors.white, colors.gray, function() page = page + 1 end) + 1
    x = ui:button(x, y, " + ADD ", colors.black, colors.lime, function() openEditor(nil) end) + 1
    x = ui:button(x, y, editMode and " DONE " or " EDIT ", colors.black, colors.yellow, function()
        editMode = not editMode
        if editMode then book:reload() setMessage("Tap a card to edit it", colors.yellow) else setMessage("") end
    end) + 1
    local right = { { " DIAL ", colors.black, colors.lightBlue, function() startDial(selected) end },
                    { dial.active and " ABORT " or " CLOSE ", colors.white, colors.red, closeGate } }
    if gate and gate.hasIris then
        local closed = gate.iris and gate.iris > 0
        right[#right + 1] = { closed and " IRIS \7 " or " IRIS ", colors.black, closed and colors.orange or colors.lightGray, toggleIris }
    end
    local width = 0
    for _, b in ipairs(right) do width = width + #b[1] + 1 end
    local rx = W - width + 1
    if rx > x then
        for _, b in ipairs(right) do rx = ui:button(rx, y, b[1], b[2], b[3], b[4]) + 1 end
    end
end

local function drawEditor()
    local w = math.min(W - 2, 46)
    local h = 14
    local x = math.floor((W - w) / 2) + 1
    local y = math.max(2, math.floor((H - h) / 2) + 1)
    ui:fill(x, y, w, h, colors.lightGray)
    ui:fill(x, y, w, 1, colors.blue)
    ui:write(x + 1, y, editor.entry and "Edit destination" or "New destination", colors.white, colors.blue)
    for i, f in ipairs(editor.fields) do
        local fy = y + 1 + i
        local focused = editor.focus == i
        ui:write(x + 1, fy, (focused and ">" or " ") .. f.label, focused and colors.black or colors.gray, colors.lightGray)
        local fw = w - 12
        local shown = f.value
        if #shown > fw - 1 then shown = shown:sub(-(fw - 1)) end
        ui:write(x + 10, fy, pad(shown .. (focused and "_" or ""), fw), colors.white, colors.gray)
        ui:hit(x, fy, x + w - 1, fy, function() editor.focus = i end)
    end
    -- colour swatches
    local sy = y + 7
    ui:write(x + 2, sy, "Colour", colors.gray, colors.lightGray)
    local sx = x + 10
    for _, name in ipairs(COLOR_CHOICES) do
        if sx + 2 > x + w - 1 then break end
        local on = editor.color == name
        ui:write(sx, sy, on and "[]" or "  ", colors.black, colors[name])
        ui:hit(sx, sy, sx + 1, sy, function() editor.color = name end)
        sx = sx + 2
    end
    ui:write(x + 2, y + 9, fit(monitor and "Type on the computer. Tab: next field." or "Tab: next field, Enter: save.", w - 4), colors.gray, colors.lightGray)
    ui:write(x + 2, y + 10, fit("26 6 14 31 11 29 / WLDQ-DQB-MT / Crater, Virgo, ..", w - 4), colors.gray, colors.lightGray)
    if editor.err then ui:write(x + 2, y + 11, fit(editor.err, w - 4), colors.red, colors.lightGray) end
    local by = y + h - 2
    local bx = x + 2
    bx = ui:button(bx, by, " Save ", colors.white, colors.green, saveEditor) + 1
    bx = ui:button(bx, by, " Cancel ", colors.white, colors.gray, function() editor = nil end) + 1
    if editor.entry then
        ui:button(bx, by, editor.confirmDelete and " Really delete? " or " Delete ", colors.white, colors.red, deleteEditor)
    end
end

local function drawNative()
    if not monitor then return end
    native.setBackgroundColor(colors.black)
    native.clear()
    native.setCursorPos(1, 1)
    native.setTextColor(colors.white)
    native.write("Gate Network Hub " .. VERSION .. " on " .. monitorName)
    native.setTextColor(colors.lightGray)
    native.setCursorPos(1, 3)
    if editor then
        local f = editor.fields[editor.focus]
        native.write("Editing " .. f.label .. ":")
        native.setCursorPos(1, 4)
        native.setTextColor(colors.orange)
        native.write("> " .. f.value)
        native.setCursorPos(1, 6)
        native.setTextColor(colors.lightGray)
        native.write("Tab / Up / Down: field   Enter: save   Esc: cancel")
    else
        native.write("Touch a card to select it, touch again to dial.")
        native.setCursorPos(1, 4)
        native.write("Ctrl+Q quits.")
    end
end

local function draw()
    ui:clearHits()
    drawTitle()
    drawTabs()
    local pages = drawGrid()
    drawStatus()
    drawButtons(pages)
    if editor then
        ui:clearHits()
        drawEditor()
    end
    drawNative()
end

---------------------------------------------------------------------------
-- Tasks
---------------------------------------------------------------------------

local function dialerTask()
    while true do
        os.pullEvent("hub_dial")
        local ok, why = gate:dial(dial.address, {
            fast = CONFIG.fastDial, symbolDelay = CONFIG.symbolDelay, chevronDelay = CONFIG.chevronDelay,
            stepTimeout = CONFIG.stepTimeout, connectTimeout = CONFIG.connectTimeout,
            abort = function() return dial.abort end,
            onStep = function() os.queueEvent("hub_redraw") end,
        })
        local entry = dial.entry
        if ok then
            setMessage("Wormhole open to " .. entry.name, colors.lightBlue)
            entry.last = "ok"
        elseif why == "aborted" then
            setMessage("Dialing aborted", colors.orange)
        else
            setMessage("Dialing " .. entry.name .. " failed: " .. tostring(why), colors.red)
            entry.last = "fail"
        end
        book:save()
        dial.active, dial.abort = false, false
        dial.endedAt, dial.failed = os.clock(), not ok
        gate:poll()
        os.queueEvent("hub_redraw")
    end
end

local function editorKey(e, held)
    local f = editor.fields[editor.focus]
    if e[1] == "key" then
        local k = e[2]
        if k == keys.tab or k == keys.down then editor.focus = editor.focus % #editor.fields + 1
        elseif k == keys.up then editor.focus = (editor.focus - 2) % #editor.fields + 1
        elseif k == keys.backspace then f.value = f.value:sub(1, -2)
        elseif k == keys.enter or k == keys.numPadEnter then
            if editor.focus < #editor.fields then editor.focus = editor.focus + 1 else saveEditor() end
        elseif k == keys.escape then editor = nil
        end
    elseif e[1] == "char" or e[1] == "paste" then
        f.value = (f.value .. tostring(e[2]):gsub("[\r\n]", " ")):sub(1, 40)
    end
end

-- Gate events are collected by a task that never calls the gate. A task that is
-- waiting for a gate call doesn't get the events that arrive in the meantime,
-- so the UI task reads them from this queue instead.
local gateEvents = {}

-- Keys, clicks and touches are queued by the listener too, for the same reason:
-- the UI task polls the gate, and input that comes in meanwhile would be lost.
local INPUT_EVENTS = {
    key = true, key_up = true, char = true, paste = true, terminate = true,
    mouse_click = true, mouse_up = true, mouse_drag = true, mouse_scroll = true,
    monitor_touch = true, term_resize = true, monitor_resize = true,
    peripheral = true, peripheral_detach = true,
}
local inputQueue = {}

local function listenerTask()
    while true do
        local e = table.pack(os.pullEventRaw())
        if Gate.EVENTS[e[1]] then
            gateEvents[#gateEvents + 1] = e
            os.queueEvent("hub_gate_event")
        elseif INPUT_EVENTS[e[1]] then
            inputQueue[#inputQueue + 1] = e
            os.queueEvent("hub_input")
        end
    end
end

local function onGateEvent(e)
    if not gate then return end
    local info = gate:event(e)
    if not info then return end
    if info.type == "incoming" or info.type == "dialin" then
        if dial.active then dial.abort = true end
        local who = info.address and book:describe(info.address)
        setMessage("Incoming wormhole" .. (who and (" from " .. who) or ""), colors.red)
    elseif info.type == "chevron" and info.incoming then
        if dial.active then dial.abort = true end
        setMessage("Incoming wormhole", colors.red)
    elseif (info.type == "closed" or info.type == "reset") and os.clock() - dial.endedAt < 2 then
        if dial.failed and info.error and info.reason then
            setMessage("Dialing " .. (dial.entry and dial.entry.name or "") .. " failed: " .. info.reason, colors.red)
        end
    elseif (info.type == "closed" or info.type == "reset") and not dial.active then
        setMessage(info.error and ("Gate reset: " .. tostring(info.reason)) or "Wormhole closed", info.error and colors.red or colors.lightGray)
    end
end

-- Ticks for the UI task. A task that is waiting for a gate call loses the events
-- that arrive meanwhile, timers included, so the UI task keeps no timers of its
-- own: it checks its deadlines on every tick, and a lost tick doesn't matter.
local function tickTask()
    while true do
        sleep(0.5)
        os.queueEvent("hub_tick")
    end
end

local function uiTask()
    local held = {}
    local nextPoll = os.clock() + CONFIG.pollInterval
    draw()
    while running do
        local e
        if #inputQueue > 0 then
            e = table.remove(inputQueue, 1)
        else
            e = table.pack(os.pullEventRaw())
            -- input comes through the queue, in order
            if INPUT_EVENTS[e[1]] then e = { n = 1, "hub_input" } end
        end
        local name = e[1]
        local redraw = true
        local polled = false
        if os.clock() >= nextPoll then
            if gate then gate:poll() end
            nextPoll = os.clock() + CONFIG.pollInterval
            polled = true
        end
        if name == "terminate" then
            running = false
        elseif name == "timer" or name == "hub_tick" then
            redraw = polled
        elseif Gate.EVENTS[name] or name == "hub_gate_event" then
            -- handled below, from the queue
        elseif name == "peripheral" then
            if not gate and Gate.isInterfaceType(peripheral.getType(e[2])) then gate = Gate.find(CONFIG.interfaceName) end
        elseif name == "peripheral_detach" then
            if gate and e[2] == gate.name then
                if dial.active then dial.abort = true end
                gate = nil
                setMessage("Stargate interface disconnected", colors.red)
            end
        elseif name == "monitor_touch" then
            if e[2] == monitorName then ui:click(e[3], e[4], 1) else redraw = false end
        elseif name == "mouse_click" then
            if not monitor then ui:click(e[3], e[4], e[2]) else redraw = false end
        elseif name == "mouse_scroll" then
            page = page + e[2]
        elseif name == "key" then
            held[e[2]] = true
            local ctrl = held[keys.leftCtrl] or held[keys.rightCtrl]
            if ctrl and e[2] == keys.q then running = false
            elseif editor then editorKey(e, held)
            elseif e[2] == keys.left or e[2] == keys.pageUp then page = page - 1
            elseif e[2] == keys.right or e[2] == keys.pageDown then page = page + 1
            elseif e[2] == keys.enter then startDial(selected)
            end
        elseif name == "key_up" then
            held[e[2]] = nil
            redraw = false
        elseif name == "char" or name == "paste" then
            if editor and not (held[keys.leftCtrl] or held[keys.rightCtrl]) then editorKey(e, held) else redraw = false end
        elseif name == "monitor_resize" or name == "term_resize" then
            layout()
        elseif name ~= "hub_redraw" then
            redraw = false
        end
        if #gateEvents > 0 then
            local pending = gateEvents
            gateEvents = {}
            for _, ge in ipairs(pending) do onGateEvent(ge) end
            redraw = true
        end
        if running and redraw then draw() end
    end
end

---------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------

Styles.apply(target, { palette = Styles.HUB })
layout()
if book.notice then
    setMessage(book.notice, colors.yellow)
elseif not gate then
    setMessage("No stargate interface found", colors.red)
else
    setMessage("Tap a destination, tap again to dial", colors.lightGray)
end

local ok, err = pcall(parallel.waitForAny, uiTask, dialerTask, listenerTask, tickTask)

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
if not ok and err ~= "Terminated" then printError(err) else print("Gate Network Hub closed.") end
