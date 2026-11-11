--[[
  Stargate Hybrid Legacy (SGHL)
  A CC:Tweaked dialing computer for the Stargate Journey mod
  (Minecraft Java Edition 1.20.1).

  It mixes the feel of the old 1.12.2 Stargate mods (an address book in the
  style of a personal dialer, a configurator page and an SGC-style status
  board) with the Stargate Journey interface API.

  Gates:      Milky Way (SG-1), Pegasus (Atlantis), Universe, Classic (movie),
              Tollan and Andromeda
  Interfaces: Basic Interface            - ring dialing on Milky Way,
                                           Universe and Classic gates
              Crystal Interface          - DHD-style dialing on every gate
              Advanced Crystal Interface - every gate, plus local and connected
                                           address, address filter and optional
                                           instant dialing

  Usage:
    sghl          run the dialing computer (connected to a gate interface)
    sghl remote   run as a pocket "personal dialer" that sends dial requests
                  over rednet to a dialing computer

  Written for Stargate Journey 0.6.54 and CC:Tweaked on Minecraft 1.20.1.
  Older 0.6.x builds that use raiseChevron/lowerChevron are handled too.
]]

local VERSION = "1.0.0"
local PROTOCOL = "sghl"

local args = { ... }
local MODE = (args[1] == "remote") and "remote" or "host"

if not term.isColor() then
  printError("Stargate Hybrid Legacy needs an Advanced Computer")
  printError("or an Advanced Pocket Computer.")
  return
end

local DIR = ""
if shell and shell.getRunningProgram then
  DIR = fs.getDir(shell.getRunningProgram())
end
local BOOK_FILE = fs.combine(DIR, "sghl_book.db")
local CONFIG_FILE = fs.combine(DIR, "sghl_config.db")

local unpack = table.unpack or unpack

-- =====================================================================
-- Utilities
-- =====================================================================

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function trim(s)
  s = tostring(s or "")
  s = s:gsub("^%s+", "")
  s = s:gsub("%s+$", "")
  return s
end

local function copy(v)
  if type(v) ~= "table" then return v end
  local r = {}
  for k, x in pairs(v) do r[k] = copy(x) end
  return r
end

-- Pads or truncates to exactly w characters.
local function fit(s, w)
  s = tostring(s or "")
  if w <= 0 then return "" end
  if #s > w then return s:sub(1, w) end
  return s .. string.rep(" ", w - #s)
end

-- Truncates to at most w characters.
local function cut(s, w)
  s = tostring(s or "")
  if w <= 0 then return "" end
  if #s > w then return s:sub(1, w) end
  return s
end

local function wrap(text, width)
  local out = {}
  width = math.max(1, width)
  for para in (tostring(text) .. "\n"):gmatch("(.-)\n") do
    local line = ""
    for word in para:gmatch("%S+") do
      while #word > width do
        if #line > 0 then
          out[#out + 1] = line
          line = ""
        end
        out[#out + 1] = word:sub(1, width)
        word = word:sub(width + 1)
      end
      if #line == 0 then
        line = word
      elseif #line + 1 + #word <= width then
        line = line .. " " .. word
      else
        out[#out + 1] = line
        line = word
      end
    end
    out[#out + 1] = line
  end
  return out
end

local function formatNumber(n)
  local s = tostring(math.floor(n))
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  out = out:gsub("^,", "")
  out = out:gsub("^%-,", "-")
  return out
end

local function formatDuration(sec)
  sec = math.max(0, math.floor(sec or 0))
  return string.format("%02d:%02d", math.floor(sec / 60), sec % 60)
end

local function prettyId(id)
  local name = tostring(id):gsub("^[%w_%-]+:", "")
  name = name:gsub("_", " ")
  name = name:gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end)
  return name
end

local function readData(path)
  if not fs.exists(path) then return nil end
  local h = fs.open(path, "r")
  if not h then return nil end
  local text = h.readAll()
  h.close()
  local ok, data = pcall(textutils.unserialize, text)
  if ok then return data end
  return nil
end

local function writeData(path, data)
  local h = fs.open(path, "w")
  if not h then return false end
  h.write(textutils.serialize(data))
  h.close()
  return true
end

-- =====================================================================
-- Addresses
-- =====================================================================

local function addressToString(addr)
  if type(addr) ~= "table" or #addr == 0 then return "-" end
  return "-" .. table.concat(addr, "-") .. "-"
end

-- Accepts "26-6-14-31-11-29", "26 6 14 31 11 29", "-26-6-...-0-" etc.
-- The point of origin (a trailing 0) is removed; it is added when dialing.
local function parseAddress(text)
  local addr = {}
  for num in tostring(text or ""):gmatch("%d+") do
    addr[#addr + 1] = tonumber(num)
  end
  if addr[#addr] == 0 then table.remove(addr) end
  return addr
end

local function cleanAddress(list)
  local addr = {}
  if type(list) ~= "table" then return addr end
  for _, v in ipairs(list) do
    local n = tonumber(v)
    if n then addr[#addr + 1] = math.floor(n) end
  end
  if addr[#addr] == 0 then table.remove(addr) end
  return addr
end

local function validateAddress(addr, maxSymbol)
  maxSymbol = maxSymbol or 47
  if type(addr) ~= "table" or #addr < 6 or #addr > 8 then
    return false, "An address needs 6 to 8 symbols (got " .. (type(addr) == "table" and #addr or 0) .. ")"
  end
  local seen = {}
  for _, s in ipairs(addr) do
    if s < 1 or s > maxSymbol then
      return false, "Symbol " .. s .. " is outside 1-" .. maxSymbol
    end
    if seen[s] then
      return false, "Symbol " .. s .. " is used twice"
    end
    seen[s] = true
  end
  return true
end

-- =====================================================================
-- Static data
-- =====================================================================

local GATE_INFO = {
  milky_way = { label = "Milky Way", symbols = 39, theme = "sg1" },
  pegasus   = { label = "Pegasus",   symbols = 48, theme = "atlantis" },
  universe  = { label = "Universe",  symbols = 36, theme = "universe" },
  classic   = { label = "Classic",   symbols = 39, theme = "movie" },
  tollan    = { label = "Tollan",    symbols = 48, theme = "tollan" },
  andromeda = { label = "Andromeda", symbols = 42, theme = "sg1" },
}

local TIER_ORDER = { "advanced_crystal_interface", "crystal_interface", "basic_interface" }
local TIER_LABEL = {
  advanced_crystal_interface = "Adv. Crystal",
  crystal_interface = "Crystal",
  basic_interface = "Basic",
}

-- Gate colour styles.
--   ring/rim: gate body and its edges     track/glyph: the symbol track
--   chevOff/chevOn: chevron housing/light  chevCore: centre of a lit chevron
--   horizon/horizon2: event horizon        sparkle: share of glittering pixels
-- sgcraft, network and jsg take their colours from the 1.12.2 era mods
-- (SGCraft, Stargate Network, JSG / Just Stargate Mod).
local THEMES = {
  sg1      = { name = "SG-1",       ring = colors.gray,      rim = colors.lightGray, track = colors.gray,      glyph = colors.lightGray, glyphLit = colors.orange,
               chevOff = colors.brown, chevOn = colors.orange,    chevCore = colors.yellow, horizon = colors.blue,      horizon2 = colors.lightBlue, sparkle = 0.03, accent = colors.orange },
  atlantis = { name = "Atlantis",   ring = colors.gray,      rim = colors.lightGray, track = colors.black,     glyph = colors.blue,      glyphLit = colors.lightBlue,
               chevOff = colors.blue,  chevOn = colors.lightBlue, chevCore = colors.white,  horizon = colors.cyan,      horizon2 = colors.lightBlue, sparkle = 0.03, accent = colors.lightBlue },
  universe = { name = "Universe",   ring = colors.lightGray, rim = colors.gray,      track = colors.lightGray, glyph = colors.gray,      glyphLit = colors.white,
               chevOff = colors.gray,  chevOn = colors.white,     chevCore = colors.white,  horizon = colors.blue,      horizon2 = colors.lightBlue, sparkle = 0.05, accent = colors.white },
  movie    = { name = "Movie",      ring = colors.gray,      rim = colors.brown,     track = colors.brown,     glyph = colors.gray,      glyphLit = colors.red,
               chevOff = colors.brown, chevOn = colors.red,       chevCore = colors.orange, horizon = colors.blue,      horizon2 = colors.lightBlue, sparkle = 0.02, accent = colors.red },
  tollan   = { name = "Tollan",     ring = colors.lightGray, rim = colors.white,     track = colors.lightGray, glyph = colors.gray,      glyphLit = colors.lightBlue,
               chevOff = colors.gray,  chevOn = colors.cyan,      chevCore = colors.white,  horizon = colors.blue,      horizon2 = colors.lightBlue, sparkle = 0.03, accent = colors.cyan },
  infinity = { name = "Infinity",   ring = colors.purple,    rim = colors.magenta,   track = colors.purple,    glyph = colors.pink,      glyphLit = colors.white,
               chevOff = colors.gray,  chevOn = colors.magenta,   chevCore = colors.pink,   horizon = colors.pink,      horizon2 = colors.white,     sparkle = 0.05, accent = colors.magenta },
  sgcraft  = { name = "SGCraft",    ring = colors.gray,      rim = colors.cyan,      track = colors.gray,      glyph = colors.lightGray, glyphLit = colors.yellow,
               chevOff = colors.brown, chevOn = colors.red,       chevCore = colors.yellow, horizon = colors.blue,      horizon2 = colors.blue,      sparkle = 0.06, accent = colors.red },
  network  = { name = "SG Network", ring = colors.gray,      rim = colors.black,     track = colors.black,     glyph = colors.cyan,      glyphLit = colors.white,
               chevOff = colors.blue,  chevOn = colors.lightBlue, chevCore = colors.white,  horizon = colors.blue,      horizon2 = colors.lightBlue, sparkle = 0.04, accent = colors.cyan },
  jsg      = { name = "JSG",        ring = colors.lightGray, rim = colors.gray,      track = colors.lightGray, glyph = colors.gray,      glyphLit = colors.orange,
               chevOff = colors.brown, chevOn = colors.orange,    chevCore = colors.yellow, horizon = colors.blue,      horizon2 = colors.lightBlue, sparkle = 0.08, accent = colors.orange },
}
local THEME_ORDER = { "auto", "sg1", "atlantis", "universe", "movie", "tollan", "infinity", "sgcraft", "network", "jsg" }

-- Gate shapes, as fractions of the outer radius.
--   inner: edge of the aperture        trackIn/trackOut: the symbol track
--   glyphs: symbols drawn on the track chevron: "v" (housing + light) or "light"
--   stopMotion: the symbols light up in turn instead of the ring spinning
local GATE_SHAPE = {
  milky_way = { inner = 0.70, trackIn = 0.75, trackOut = 0.90, glyphs = 39, chevron = "v" },
  classic   = { inner = 0.68, trackIn = 0.74, trackOut = 0.88, glyphs = 39, chevron = "v", bigChevrons = true },
  pegasus   = { inner = 0.72, trackIn = 0.77, trackOut = 0.91, glyphs = 36, chevron = "v", stopMotion = true },
  andromeda = { inner = 0.72, trackIn = 0.77, trackOut = 0.91, glyphs = 42, chevron = "v", stopMotion = true },
  universe  = { inner = 0.74, trackIn = 0.77, trackOut = 0.97, glyphs = 36, chevron = "light", segments = true },
  tollan    = { inner = 0.86, glyphs = 0, chevron = "light", lightSize = 0.1 },
}

-- Stargate Journey feedback codes (StargateInfo.Feedback)
local FEEDBACK = {
  [0] = "None", [-1] = "Unknown error",
  [1] = "Symbol encoded", [-2] = "Symbol already in address",
  [-3] = "Symbol out of bounds", [-4] = "Can't encode while connected",
  [2] = "Connected (system-wide)", [3] = "Connected (interstellar)",
  [4] = "Connected (intergalactic)",
  [-5] = "Incomplete address", [-6] = "Invalid address",
  [-7] = "Not enough power", [-8] = "This gate is obstructed",
  [-9] = "Target gate is obstructed", [-10] = "A gate can't dial itself",
  [-11] = "Same solar system", [-12] = "Target is already connected",
  [-13] = "No galaxy", [-14] = "No dimensions at that address",
  [-15] = "No stargates at that address", [-16] = "Restricted network (local)",
  [-17] = "Restricted network (target)", [-19] = "System-wide dialing is disabled",
  [-20] = "Target not on local whitelist", [-21] = "Not on target's whitelist",
  [-22] = "Target on local blacklist", [-23] = "Blacklisted by target",
  [7] = "Disconnected", [8] = "Closed by point of origin",
  [9] = "Closed by the network", [10] = "Auto-closed by DHD",
  [-24] = "Max connection time exceeded", [-25] = "Ran out of power",
  [-26] = "Connection rerouted", [-27] = "Only the dialing gate can close",
  [-28] = "Connection still forming", [-29] = "Remote gate destroyed",
  [-30] = "Could not reach target", [-31] = "Interrupted by incoming wormhole",
  [11] = "Chevron opened", [12] = "Rotating", [-32] = "Rotation blocked",
  [-33] = "Not rotating", [13] = "Rotation stopped",
  [-34] = "Chevron already open", [-35] = "Chevron already closed",
  [-36] = "Chevron not open", [-37] = "Target not loaded",
  [-38] = "Gate is outside the network", [-39] = "Target is outside the network",
}

local function feedbackText(code, msg)
  if code == nil then return "-" end
  return FEEDBACK[code] or (msg and tostring(msg)) or ("Feedback " .. tostring(code))
end

-- rotation and chevron notices that would hide the more useful last result
local QUIET_FEEDBACK = { [0] = true, [11] = true, [12] = true, [13] = true, [-32] = true, [-33] = true, [-34] = true, [-35] = true }

local function isDialError(code)
  if type(code) ~= "number" or code >= 0 then return false end
  -- harmless rotation/chevron state notices
  return not (code == -32 or code == -33 or code == -34 or code == -35)
end

-- Default addresses from Stargate Journey's built-in address regions.
-- Servers can randomize these, so edit the book if a dial fails.
local DEFAULT_BOOK = {
  { name = "Abydos",            address = { 26, 6, 14, 31, 11, 29 },    group = "Milky Way" },
  { name = "Chulak",            address = { 8, 1, 22, 14, 36, 19 },     group = "Milky Way" },
  { name = "Earth (Overworld)", address = { 27, 25, 4, 35, 10, 28 },    group = "Milky Way" },
  { name = "Nether",            address = { 27, 23, 4, 34, 12, 28 },    group = "Milky Way" },
  { name = "The End",           address = { 13, 24, 2, 19, 3, 30 },     group = "Milky Way" },
  { name = "Cavum Tenebrae",    address = { 18, 7, 3, 36, 25, 15 },     group = "Milky Way" },
  { name = "Tollan",            address = { 5, 32, 26, 36, 10, 17 },    group = "Milky Way" },
  { name = "Rima",              address = { 33, 20, 10, 22, 3, 17 },    group = "Milky Way" },
  { name = "Unitas",            address = { 2, 27, 8, 34, 24, 15 },     group = "Milky Way" },
  { name = "Proxima Centauri",  address = { 26, 20, 4, 36, 9, 27 },     group = "Milky Way" },
  { name = "Lantea",            address = { 18, 20, 1, 15, 14, 7, 19 }, group = "Pegasus, 8 chevrons" },
  { name = "Athos",             address = { 18, 21, 14, 24, 1, 26, 28 }, group = "Pegasus, 8 chevrons" },
  { name = "Othala",            address = { 10, 26, 22, 15, 32, 2, 8 }, group = "Ida, 8 chevrons" },
  { name = "Lantea (local)",    address = { 29, 5, 17, 34, 6, 12 },     group = "From a Pegasus gate" },
  { name = "Athos (local)",     address = { 21, 14, 24, 1, 26, 28 },    group = "From a Pegasus gate" },
}

-- Stand-in characters from the ComputerCraft font, one per symbol, shown
-- next to each address like the glyph strip of a personal dialer.
-- They are not the real gate glyphs.
local GLYPH_CHARS = {}
do
  local codes = {
    164, 165, 167, 169, 170, 172, 174, 176, 177, 181, 182, 186, 188, 189, 190, 191,
    197, 198, 199, 208, 215, 216, 222, 223, 229, 230, 231, 240, 241, 247, 248, 254,
    163, 166, 168, 171, 175, 178, 179, 185, 187, 192, 196, 201, 209, 211, 220, 233,
  }
  for i, c in ipairs(codes) do GLYPH_CHARS[i] = string.char(c) end
end

local function glyphString(addr)
  local out = {}
  for i, s in ipairs(addr or {}) do out[i] = GLYPH_CHARS[s] or "?" end
  return table.concat(out)
end

-- Physical chevron order used by Stargate Journey (Dialing.java)
local CHEVRON_CFG = {
  [7] = { 1, 2, 3, 6, 7, 8, 4, 5 },
  [8] = { 1, 2, 3, 4, 6, 7, 8, 5 },
  [9] = { 1, 2, 3, 4, 5, 6, 7, 8 },
}

-- =====================================================================
-- Config and address book
-- =====================================================================

local DEFAULT_CONFIG = {
  autoClose = true,        -- close an outgoing wormhole after someone steps through
  autoCloseDelay = 5,      -- seconds after the last traveller
  maxOpenSeconds = 0,      -- close an outgoing wormhole after this long (0 = off)
  irisOnIncoming = true,   -- close the iris when an incoming wormhole forms
  restoreIris = true,      -- put the iris back how it was after the wormhole closes
  sgcStyle = false,        -- Milky Way + Basic Interface: open, encode, close
  stepDelay = 1,           -- seconds between ring dialing steps
  directEngage = false,    -- Advanced Crystal Interface: lock symbols instantly
  showGlyphs = true,
  theme = "auto",
  monitorBoard = true,
  monitorScale = 0.5,
  interface = "",          -- peripheral name, blank = find automatically
  remoteEnabled = false,   -- host: accept dial requests from pocket dialers
  remotePassword = "",
  remoteHost = "",         -- remote: host name to use, blank = first found
}

local config = readData(CONFIG_FILE)
if type(config) ~= "table" then config = {} end
for k, v in pairs(DEFAULT_CONFIG) do
  if type(config[k]) ~= type(v) then config[k] = v end
end

local function saveConfig()
  writeData(CONFIG_FILE, config)
end

local book = readData(BOOK_FILE)
if type(book) ~= "table" then
  book = copy(DEFAULT_BOOK)
  writeData(BOOK_FILE, book)
else
  local clean = {}
  for _, e in ipairs(book) do
    if type(e) == "table" then
      clean[#clean + 1] = {
        name = tostring(e.name or "Unnamed"),
        address = cleanAddress(e.address),
        group = tostring(e.group or ""),
      }
    end
  end
  book = clean
end

local function saveBook()
  writeData(BOOK_FILE, book)
end

-- =====================================================================
-- Shared state (the UI only reads this table, so a pocket remote can
-- show the same pages from a copy sent over rednet)
-- =====================================================================

local state = {
  mode = MODE,
  status = "offline",   -- offline idle dialing engaging incoming open_out open_in
  problem = "Looking for a Stargate interface...",
  gateKind = nil, gateLabel = "-", autoTheme = "sg1", maxSymbol = 47,
  tier = "-", tierId = nil, interfaceName = nil, dialMethod = nil,
  hasIris = false, irisName = nil, irisPct = 0, irisClosed = false,
  hasFilter = false, filterType = nil,
  localAddress = nil, remoteAddress = nil, dialedAddress = nil,
  target = nil, chevrons = 0, lit = {}, rotation = 0,
  openSeconds = 0, energy = nil,
  feedbackCode = nil, feedbackText = "-",
  host = nil,
}

local logLines = {}

local function redraw()
  os.queueEvent("sghl_redraw")
end

local function log(kind, msg)
  table.insert(logLines, 1, {
    t = textutils.formatTime(os.time(), true),
    kind = kind,
    msg = tostring(msg),
  })
  if #logLines > 100 then table.remove(logLines) end
  redraw()
end

local function setFeedback(code, msg)
  if code == nil then return end
  state.feedbackCode = code
  state.feedbackText = feedbackText(code, msg)
end

local function rebuildLit(n, complete)
  state.lit = {}
  if not n or n <= 0 then return end
  local regular = complete and (n - 1) or n
  local total = complete and n or math.max(7, n + 1)
  local cfg = CHEVRON_CFG[clamp(total, 7, 9)]
  for i = 1, math.min(regular, 8) do state.lit[cfg[i]] = true end
  if complete then state.lit[0] = true end
end

local function findModem()
  local wireless, any = nil, nil
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "modem" then
      any = any or name
      local m = peripheral.wrap(name)
      if m and m.isWireless and m.isWireless() then wireless = wireless or name end
    end
  end
  return wireless or any
end

-- =====================================================================
-- Gate controller (dialing computer)
-- =====================================================================

local Gate = { p = nil, name = nil, typeId = "" }
local Dial = { active = false, abort = false, pending = nil, failCode = nil, failMsg = nil }
local irisMemory = nil   -- iris position before it was closed automatically
local autoCloseAt = nil  -- os.clock() deadline for Auto Close
local maxOpenAt = nil    -- os.clock() deadline for the open time limit
local openedAt = nil     -- os.clock() when the wormhole opened

local function has(fname)
  return Gate.p ~= nil and type(Gate.p[fname]) == "function"
end

-- Returns ok, result1, result2
local function tryCall(fname, ...)
  if not has(fname) then return false, "missing " .. fname end
  return pcall(Gate.p[fname], ...)
end

-- Returns the results, or nil on error
local function call(fname, ...)
  local ok, a, b = tryCall(fname, ...)
  if ok then return a, b end
  return nil
end

local function hasType(name, t)
  if peripheral.hasType then
    local ok, res = pcall(peripheral.hasType, name, t)
    if ok and res then return true end
  end
  return peripheral.getType(name) == t
end

local function findInterface()
  if config.interface ~= "" and peripheral.isPresent(config.interface) then
    local t = peripheral.getType(config.interface)
    return peripheral.wrap(config.interface), config.interface, t
  end
  for _, t in ipairs(TIER_ORDER) do
    local first = nil
    for _, name in ipairs(peripheral.getNames()) do
      if hasType(name, t) then
        local p = peripheral.wrap(name)
        if p and p.getChevronsEngaged then return p, name, t end
        first = first or name
      end
    end
    if first then return peripheral.wrap(first), first, t end
  end
  return nil
end

-- Ring angle in degrees, so the symbol track on screen turns with the gate.
function Gate.readRotation()
  if has("getRotationDegrees") then
    local deg = call("getRotationDegrees")
    if type(deg) == "number" then return deg end
  end
  if has("getCurrentSymbol") then
    local s = call("getCurrentSymbol")
    local info = GATE_INFO[state.gateKind or ""]
    if type(s) == "number" and info then return s * 360 / info.symbols end
  end
  return 0
end

function Gate.poll()
  if not has("getChevronsEngaged") then return end
  local prev = state.status
  state.rotation = Gate.readRotation()
  local connected = call("isStargateConnected") and true or false
  local chevrons = call("getChevronsEngaged") or 0
  local wormhole = call("isWormholeOpen")
  local out = call("isStargateDialingOut")
  state.chevrons = chevrons

  if connected then
    if wormhole == nil then wormhole = true end
    if out == nil then
      -- older builds: keep what the events told us, fail safe to incoming
      out = (prev == "open_out" or prev == "dialing" or prev == "engaging")
    end
    if wormhole then
      state.status = out and "open_out" or "open_in"
    else
      state.status = out and "engaging" or "incoming"
    end
  elseif Dial.active or chevrons > 0 then
    state.status = "dialing"
  else
    state.status = "idle"
  end

  local open = state.status == "open_out" or state.status == "open_in"
  if open then
    local ticks = call("getOpenTime")
    if not openedAt then openedAt = os.clock() - (ticks and ticks / 20 or 0) end
    state.openSeconds = ticks and (ticks / 20) or (os.clock() - openedAt)
    local ca = call("getConnectedAddress")
    if type(ca) == "table" and #ca > 0 then state.remoteAddress = ca end
  else
    state.openSeconds = 0
    openedAt = nil
  end

  if state.status == "dialing" and not Dial.active then
    local da = call("getDialedAddress")
    if type(da) == "table" then state.dialedAddress = da end
  end

  if chevrons == 0 and not connected then
    state.lit = {}
    state.remoteAddress = nil
    state.dialedAddress = nil
    if not Dial.active then state.target = nil end
  else
    -- rebuild the chevron lights only if events were clearly missed
    local count = 0
    for _ in pairs(state.lit) do count = count + 1 end
    if count > chevrons or count < chevrons - 1 then rebuildLit(chevrons, open) end
  end

  if not Dial.active then
    local code, msg = call("getRecentFeedback")
    if type(code) == "number" and not QUIET_FEEDBACK[code] then setFeedback(code, msg) end
  end
  state.energy = call("getStargateEnergy")
  if state.hasIris then
    local iris = call("getIris")
    state.irisName = iris and prettyId(iris) or nil
    local pct = call("getIrisProgressPercentage")
    state.irisPct = pct and math.floor(pct + 0.5) or 0
    state.irisClosed = state.irisName ~= nil and state.irisPct >= 100
  end
  if state.hasFilter then state.filterType = call("getFilterType") end
  if prev ~= state.status then redraw() end
end

function Gate.detect()
  local p, name, ptype = findInterface()
  Gate.p, Gate.name = p, name
  state.interfaceName = name
  state.tierId = ptype
  state.tier = ptype and (TIER_LABEL[ptype] or ptype) or "-"
  state.lit = {}
  if not p then
    state.status = "offline"
    state.problem = "No Stargate interface found. Put a Basic, Crystal or Advanced Crystal Interface against the gate and connect it to this computer."
    return false
  end
  if not has("getChevronsEngaged") then
    state.status = "offline"
    state.problem = "The " .. state.tier .. " Interface is not facing a Stargate. Turn its front towards a gate block."
    return false
  end

  Gate.typeId = call("getStargateType") or ""
  local kind = nil
  for k in pairs(GATE_INFO) do
    if Gate.typeId:find(k, 1, true) then kind = k end
  end
  if not kind then
    if has("openChevron") or has("raiseChevron") then kind = "milky_way" else kind = "unknown" end
  end
  local info = GATE_INFO[kind] or {
    label = (Gate.typeId ~= "" and prettyId(Gate.typeId) or "Unknown"),
    symbols = 48,
    theme = "sg1",
  }
  state.gateKind = kind
  state.gateLabel = info.label
  state.maxSymbol = info.symbols - 1
  state.autoTheme = info.theme
  state.hasIris = has("getIris")
  state.hasFilter = has("getFilterType")
  state.problem = nil

  if has("engageSymbol") then
    state.dialMethod = "engage"
  elseif has("openChevron") or has("raiseChevron") then
    state.dialMethod = "lever"
  elseif has("rotateClockwise") and has("encodeChevron") then
    state.dialMethod = "rotate"
  else
    state.dialMethod = nil
    state.problem = info.label .. " gates need a Crystal Interface to dial from a computer."
  end

  local la = call("getLocalAddress")
  state.localAddress = (type(la) == "table" and #la > 0) and la or nil
  state.status = "idle"
  Gate.poll()
  return true
end

local function irisAuto()
  if not (config.irisOnIncoming and state.hasIris and state.irisName) then return end
  if irisMemory ~= nil then return end
  irisMemory = state.irisClosed and "closed" or "open"
  if irisMemory == "open" then
    call("closeIris")
    log("warn", "Iris closing for the incoming wormhole")
  end
end

function Gate.afterClose()
  autoCloseAt, maxOpenAt, openedAt = nil, nil, nil
  state.remoteAddress = nil
  if not Dial.active then
    state.status = "idle"
    state.lit = {}
    state.chevrons = 0
    state.target = nil
    state.dialedAddress = nil
  end
  if irisMemory == "open" and config.restoreIris and state.irisName then
    call("openIris")
    log("info", "Iris opening again")
  end
  irisMemory = nil
end

function Gate.handleEvent(ev)
  local e = ev[1]
  if type(e) ~= "string" then return end
  if e:sub(1, 9) ~= "stargate_" and e ~= "iris_thud" then return end
  if Gate.name and ev[2] ~= Gate.name then return end

  if e == "stargate_chevron_engaged" then
    local count, chevron, incoming, symbol = ev[3], ev[4], ev[5], ev[6]
    if type(count) == "number" then state.chevrons = count end
    if type(chevron) == "number" then state.lit[chevron] = true end
    if incoming then
      if state.status ~= "open_in" then state.status = "incoming" end
      irisAuto()
      log("warn", "Incoming chevron " .. tostring(count) .. " locked")
    else
      if state.status == "idle" then state.status = "dialing" end
      if symbol == 0 then
        log("info", "Chevron " .. tostring(count) .. " locked (point of origin)")
      else
        log("info", "Chevron " .. tostring(count) .. " locked" .. (symbol and (" (symbol " .. tostring(symbol) .. ")") or ""))
      end
    end
  elseif e == "stargate_incoming_connection" then
    state.status = "incoming"
    irisAuto()
    log("warn", "Incoming connection!")
  elseif e == "stargate_stargate_engaged" then
    if state.status ~= "incoming" then state.status = "engaging" end
  elseif e == "stargate_incoming_wormhole" then
    state.status = "open_in"
    openedAt = os.clock()
    if type(ev[3]) == "table" and #ev[3] > 0 then state.remoteAddress = ev[3] end
    irisAuto()
    log("warn", "Incoming wormhole" .. (state.remoteAddress and (" from " .. addressToString(state.remoteAddress)) or ""))
  elseif e == "stargate_outgoing_wormhole" then
    state.status = "open_out"
    openedAt = os.clock()
    if type(ev[3]) == "table" and #ev[3] > 0 then state.remoteAddress = ev[3] end
    if config.maxOpenSeconds > 0 then maxOpenAt = os.clock() + config.maxOpenSeconds end
    log("ok", "Wormhole established" .. (state.target and (" to " .. state.target.name) or ""))
  elseif e == "stargate_disconnected" then
    setFeedback(ev[3])
    log("info", "Wormhole closed: " .. feedbackText(ev[3]))
    Gate.afterClose()
  elseif e == "stargate_reset" then
    local code, msg = ev[3], ev[4]
    setFeedback(code, msg)
    if type(code) == "number" and code < 0 then
      if Dial.active then
        Dial.failCode, Dial.failMsg = code, msg
      else
        log("err", "Gate reset: " .. feedbackText(code, msg))
      end
    end
    Gate.afterClose()
  elseif e == "stargate_deconstructing_entity" then
    local who, lost = ev[4], ev[6]
    log("travel", tostring(who or "Something") .. (lost and " was lost in the wormhole" or " stepped through"))
    if state.status == "open_out" and config.autoClose then
      autoCloseAt = os.clock() + config.autoCloseDelay
    end
  elseif e == "stargate_reconstructing_entity" then
    log("travel", tostring(ev[4] or "Something") .. " arrived through the gate")
  elseif e == "iris_thud" then
    log("warn", tostring(ev[4] or "Something") .. " hit the iris")
  elseif e == "stargate_message_received" then
    log("info", "Message: " .. tostring(ev[3]))
  else
    return
  end
  redraw()
end

-- ---------------------------------------------------------------------
-- Dialing
-- ---------------------------------------------------------------------

local function waitUntil(pred, timeout)
  local deadline = os.clock() + timeout
  while true do
    if Dial.abort then return false, "Dialing aborted" end
    if Dial.failCode then return false, feedbackText(Dial.failCode, Dial.failMsg) end
    if pred() then return true end
    if os.clock() >= deadline then return false, "timeout" end
    sleep(0.1)
  end
end

-- Spins the ring to a symbol, changing direction every chevron like the show.
local function rotateTo(sym, i)
  if call("isCurrentSymbol", sym) then return true end
  local fn = (i % 2 == 1) and "rotateAntiClockwise" or "rotateClockwise"
  local ok, code = tryCall(fn, sym)
  if not ok then return false, tostring(code) end
  if isDialError(code) then return false, feedbackText(code) end
  local done, why = waitUntil(function() return call("isCurrentSymbol", sym) end, 90)
  if not done then
    if why == "timeout" then why = "The ring never reached symbol " .. sym end
    return false, why
  end
  return true
end

-- Crystal / Advanced Crystal Interface: the gate dials like a DHD
local function dialEngage(addr)
  local direct = config.directEngage and state.tierId == "advanced_crystal_interface"
  for i, sym in ipairs(addr) do
    if Dial.abort then return false, "Dialing aborted" end
    local ok, code, msg = tryCall("engageSymbol", sym, direct)
    if not ok then return false, tostring(code) end
    setFeedback(code, msg)
    if isDialError(code) then return false, feedbackText(code, msg) end
    if sym ~= 0 then
      local done, why = waitUntil(function()
        return (call("getChevronsEngaged") or 0) >= i
      end, 60)
      if not done then
        if why == "timeout" then why = "Chevron " .. i .. " did not lock" end
        return false, why
      end
    end
  end
  return true
end

-- Milky Way + Basic Interface: spin, open the top chevron, (encode), close
local function dialLever(addr)
  local openFn = has("openChevron") and "openChevron" or "raiseChevron"
  local closeFn = has("closeChevron") and "closeChevron" or "lowerChevron"
  local d = math.max(0, tonumber(config.stepDelay) or 1)
  for i, sym in ipairs(addr) do
    if Dial.abort then return false, "Dialing aborted" end
    local ok, why = rotateTo(sym, i)
    if not ok then return false, why end
    if d > 0 then sleep(d / 2) end
    if Dial.abort then return false, "Dialing aborted" end

    local okOpen, code = tryCall(openFn)
    if not okOpen then return false, tostring(code) end
    if isDialError(code) then return false, feedbackText(code) end
    if d > 0 then sleep(d) end

    local encoded = false
    if config.sgcStyle and sym ~= 0 and has("encodeChevron") then
      local okEnc, codeEnc = tryCall("encodeChevron")
      if okEnc and isDialError(codeEnc) then return false, feedbackText(codeEnc) end
      encoded = okEnc
      if d > 0 then sleep(d / 2) end
    end

    local okClose, codeClose = tryCall(closeFn)
    if not okClose then return false, tostring(codeClose) end
    -- after encodeChevron the symbol is already in the address, so closing reports -2
    if not (encoded and codeClose == -2) then
      setFeedback(codeClose)
      if isDialError(codeClose) then return false, feedbackText(codeClose) end
    end
    if d > 0 and sym ~= 0 then sleep(d / 2) end
  end
  return true
end

-- Universe / Classic + Basic Interface: spin, then encode
local function dialRotate(addr)
  local d = math.max(0, tonumber(config.stepDelay) or 1)
  for i, sym in ipairs(addr) do
    if Dial.abort then return false, "Dialing aborted" end
    local ok, why = rotateTo(sym, i)
    if not ok then return false, why end
    if d > 0 then sleep(d / 2) end
    local okEnc, code = tryCall("encodeChevron")
    if not okEnc then return false, tostring(code) end
    setFeedback(code)
    if isDialError(code) then return false, feedbackText(code) end
    if d > 0 and sym ~= 0 then sleep(d / 2) end
  end
  return true
end

local function runDial(req)
  Dial.active, Dial.abort, Dial.failCode, Dial.failMsg = true, false, nil, nil
  local addr = copy(req.address)
  addr[#addr + 1] = 0

  -- clear anything a DHD or an earlier dial left on the gate
  if (call("getChevronsEngaged") or 0) > 0 or (has("isChevronOpen") and call("isChevronOpen")) then
    call("disconnectStargate")
    sleep(0.5)
  end
  Dial.failCode, Dial.failMsg = nil, nil

  state.status = "dialing"
  state.target = { name = req.name, address = copy(req.address) }
  state.lit, state.chevrons = {}, 0
  state.remoteAddress, state.dialedAddress = nil, nil
  log("info", "Dialing " .. req.name .. " " .. addressToString(req.address))

  local ok, err
  if state.dialMethod == "engage" then
    ok, err = dialEngage(addr)
  elseif state.dialMethod == "lever" then
    ok, err = dialLever(addr)
  else
    ok, err = dialRotate(addr)
  end

  if ok then
    waitUntil(function()
      return call("isStargateConnected") or (call("getChevronsEngaged") or 0) == 0
    end, 20)
    if not call("isStargateConnected") then
      ok = false
      if Dial.failCode then
        err = feedbackText(Dial.failCode, Dial.failMsg)
      else
        local code, msg = call("getRecentFeedback")
        err = isDialError(code) and feedbackText(code, msg) or "No connection"
      end
    end
  end

  local aborted = Dial.abort
  Dial.active, Dial.abort = false, false
  if aborted then
    log("warn", "Dialing aborted")
    state.target = nil
  elseif not ok then
    log("err", "Dial failed: " .. tostring(err))
    state.feedbackText = tostring(err)
    call("disconnectStargate")
    state.target = nil
  end
  Gate.poll()
  redraw()
end

function Gate.requestDial(entry)
  if not entry then return false end
  if Dial.active or Dial.pending then
    log("warn", "Already dialing")
    return false
  end
  if not state.dialMethod then
    log("err", state.problem or "This gate can't be dialed")
    return false
  end
  local addr = cleanAddress(entry.address)
  local ok, err = validateAddress(addr, state.maxSymbol)
  if not ok then
    log("err", entry.name .. ": " .. err)
    return false
  end
  local s = state.status
  if s == "open_out" or s == "open_in" or s == "incoming" or s == "engaging" then
    log("warn", "The gate is busy")
    return false
  end
  Dial.pending = { name = tostring(entry.name or "?"), address = addr }
  os.queueEvent("sghl_dial")
  return true
end

function Gate.close()
  if Dial.active then
    Dial.abort = true
    if has("endRotation") then call("endRotation") end
  end
  local ok, res = tryCall("disconnectStargate")
  if state.status == "open_in" and ok and res == false then
    log("warn", "Only the dialing gate can close this wormhole")
  else
    log("info", "Gate shutdown requested")
  end
  autoCloseAt, maxOpenAt = nil, nil
  redraw()
end

function Gate.iris(action)
  if not state.hasIris then
    log("warn", state.gateLabel .. " gates have no iris")
    return
  end
  if not state.irisName then
    log("warn", "No iris is installed in the gate")
    return
  end
  if action == "toggle" then
    action = ((state.irisPct or 0) >= 50) and "open" or "close"
  end
  if action == "open" then
    call("openIris")
  elseif action == "close" then
    call("closeIris")
  else
    call("stopIris")
    action = "stop"
  end
  irisMemory = nil
  log("info", "Iris: " .. action)
end

function Gate.setFilter(t)
  if not has("setFilterType") then return end
  call("setFilterType", t)
  state.filterType = call("getFilterType")
  log("info", "Address filter: " .. (t == 1 and "whitelist" or t == -1 and "blacklist" or "off"))
end

function Gate.filterAdd(entry)
  if not entry then return end
  local fn = (state.filterType == -1) and "addToBlacklist" or "addToWhitelist"
  local ok, err = tryCall(fn, cleanAddress(entry.address))
  if ok then
    log("ok", entry.name .. " added to the " .. (fn == "addToBlacklist" and "blacklist" or "whitelist"))
  else
    log("err", tostring(err))
  end
end

function Gate.filterClear()
  local fn = (state.filterType == -1) and "clearBlacklist" or "clearWhitelist"
  call(fn)
  log("info", (fn == "clearBlacklist" and "Blacklist" or "Whitelist") .. " cleared")
end

local function gateLoop()
  local timer = os.startTimer(0)
  local spinTimer = nil
  local lastDetect = -100
  while true do
    -- follow the ring closely while it may be turning
    if not spinTimer and Gate.p and (Dial.active or state.status == "dialing")
      and (has("getRotationDegrees") or has("getCurrentSymbol")) then
      spinTimer = os.startTimer(0.2)
    end
    local ev = { os.pullEvent() }
    local e = ev[1]
    if e == "timer" and ev[2] == spinTimer then
      spinTimer = nil
      if Gate.p then state.rotation = Gate.readRotation() end
    elseif e == "timer" and ev[2] == timer then
      if state.status == "offline" or not Gate.p then
        if os.clock() - lastDetect >= 3 then
          lastDetect = os.clock()
          Gate.detect()
        end
      else
        Gate.poll()
      end
      local now = os.clock()
      if autoCloseAt and now >= autoCloseAt then
        autoCloseAt = nil
        if state.status == "open_out" then
          log("info", "Auto Close: shutting down the wormhole")
          Gate.close()
        end
      end
      if maxOpenAt and now >= maxOpenAt then
        maxOpenAt = nil
        if state.status == "open_out" then
          log("info", "Time limit reached: shutting down the wormhole")
          Gate.close()
        end
      end
      redraw()
      timer = os.startTimer(1)
    elseif e == "peripheral" then
      if state.status == "offline" then lastDetect = -100 end
    elseif e == "peripheral_detach" then
      if ev[2] == Gate.name then
        Gate.p = nil
        state.status = "offline"
        state.problem = "The Stargate interface was disconnected."
        log("err", "Interface disconnected")
      end
    else
      Gate.handleEvent(ev)
    end
  end
end

local function dialWorker()
  while true do
    os.pullEvent("sghl_dial")
    local req = Dial.pending
    Dial.pending = nil
    if req then runDial(req) end
  end
end

-- ---------------------------------------------------------------------
-- Remote dialers: the host side
-- ---------------------------------------------------------------------

local function publicState()
  local s = copy(state)
  s.mode = nil
  return s
end

local function handleRemote(id, msg)
  if type(msg) ~= "table" then return end
  if config.remotePassword ~= "" and msg.pass ~= config.remotePassword then
    rednet.send(id, { type = "denied" }, PROTOCOL)
    return
  end
  if msg.type == "dial" then
    local name = cut(tostring(msg.name or "Remote request"), 40)
    log("info", "Pocket dialer #" .. id .. " asks for " .. name)
    Gate.requestDial({ name = name, address = cleanAddress(msg.address) })
  elseif msg.type == "close" then
    log("info", "Pocket dialer #" .. id .. " asks to close the gate")
    Gate.close()
  elseif msg.type == "iris" then
    Gate.iris(msg.action)
  end
  local recent = {}
  for i = 1, math.min(6, #logLines) do recent[i] = logLines[i] end
  rednet.send(id, { type = "state", state = publicState(), log = recent }, PROTOCOL)
end

local function hostRemoteLoop()
  local opened = nil
  while true do
    if config.remoteEnabled then
      if not opened then
        local m = findModem()
        if m then
          rednet.open(m)
          opened = m
          local hostName = os.getComputerLabel() or ("sghl-" .. os.getComputerID())
          pcall(rednet.host, PROTOCOL, hostName)
          log("info", "Pocket dialers can reach this gate as '" .. hostName .. "'")
        else
          sleep(3)
        end
      end
      if opened then
        local id, msg = rednet.receive(PROTOCOL, 1)
        if id then handleRemote(id, msg) end
      end
    else
      if opened then
        pcall(rednet.unhost, PROTOCOL)
        pcall(rednet.close, opened)
        opened = nil
        log("info", "Pocket dialer access turned off")
      end
      sleep(1)
    end
  end
end

-- ---------------------------------------------------------------------
-- Remote dialers: the pocket side
-- ---------------------------------------------------------------------

local Remote = { modem = nil, hostId = nil, hostName = nil, lastSeen = 0 }

local function remoteSend(msg)
  if not Remote.hostId then
    log("warn", "No dialing computer found yet")
    return false
  end
  msg.pass = config.remotePassword
  rednet.send(Remote.hostId, msg, PROTOCOL)
  return true
end

local function remoteClientLoop()
  local timer = os.startTimer(0)
  while true do
    local ev = { os.pullEvent() }
    if ev[1] == "timer" and ev[2] == timer then
      if not Remote.modem then
        local m = findModem()
        if m then
          rednet.open(m)
          Remote.modem = m
        end
      end
      if not Remote.modem then
        state.status = "offline"
        state.problem = "Put a wireless or ender modem on this pocket computer."
      elseif not Remote.hostId or os.clock() - Remote.lastSeen > 6 then
        state.status = "offline"
        state.problem = "Searching for a dialing computer..."
        redraw()
        local host = (config.remoteHost ~= "") and config.remoteHost or nil
        local id = rednet.lookup(PROTOCOL, host)
        if id then
          Remote.hostId = id
          Remote.hostName = host or ("#" .. id)
          Remote.lastSeen = os.clock()
          rednet.send(id, { type = "poll", pass = config.remotePassword }, PROTOCOL)
        else
          Remote.hostId = nil
        end
      else
        rednet.send(Remote.hostId, { type = "poll", pass = config.remotePassword }, PROTOCOL)
      end
      redraw()
      timer = os.startTimer(1)
    elseif ev[1] == "rednet_message" and ev[4] == PROTOCOL and ev[2] == Remote.hostId then
      local msg = ev[3]
      if type(msg) == "table" then
        Remote.lastSeen = os.clock()
        if msg.type == "denied" then
          state.status = "offline"
          state.problem = "The dialing computer refused the password. Set it on the Config page."
        elseif msg.type == "state" and type(msg.state) == "table" then
          for k, v in pairs(msg.state) do state[k] = v end
          state.mode = "remote"
          state.host = Remote.hostName
          if type(msg.log) == "table" then
            for i = #msg.log, 1, -1 do
              local line = msg.log[i]
              local known = false
              for j = 1, math.min(#logLines, 10) do
                if logLines[j].t == line.t and logLines[j].msg == line.msg then known = true end
              end
              if not known and type(line) == "table" then
                table.insert(logLines, 1, line)
                if #logLines > 100 then table.remove(logLines) end
              end
            end
          end
        end
        redraw()
      end
    end
  end
end

-- =====================================================================
-- What the UI buttons call
-- =====================================================================

local Controller = {}
if MODE == "host" then
  Controller.dial = Gate.requestDial
  Controller.close = Gate.close
  Controller.iris = Gate.iris
else
  Controller.dial = function(entry)
    local ok = validateAddress(cleanAddress(entry.address), 47)
    if not ok then return false end
    log("info", "Requesting " .. entry.name)
    return remoteSend({ type = "dial", name = entry.name, address = cleanAddress(entry.address) })
  end
  Controller.close = function() return remoteSend({ type = "close" }) end
  Controller.iris = function(action) return remoteSend({ type = "iris", action = action }) end
end

-- =====================================================================
-- Drawing
-- =====================================================================

local native = term.current()
local W, H = native.getSize()
local scr = window.create(native, 1, 1, W, H, true)

local UI = {
  view = "book",
  sel = 1, scroll = 0, search = "",
  filtered = {},
  logScroll = 0, cfgScroll = 0,
  modal = nil,
  buttons = {},
  monButtons = {},
  cursor = nil,
  -- animation
  frame = 0, animTimer = nil, lastStatus = nil,
  kawooshStart = nil, kawooshPhase = nil,
}

local BLIT = {}
local function toBlit(c)
  if BLIT[c] then return BLIT[c] end
  local b
  if colors.toBlit then
    b = colors.toBlit(c)
  else
    local i, v = 0, c
    while v > 1 do v = v / 2; i = i + 1 end
    b = ("0123456789abcdef"):sub(i + 1, i + 1)
  end
  BLIT[c] = b
  return b
end

local function theme()
  local key = config.theme
  if key == "auto" or not THEMES[key] then key = state.autoTheme or "sg1" end
  return THEMES[key] or THEMES.sg1
end

local function put(t, x, y, s, fg, bg)
  t.setCursorPos(x, y)
  if bg then t.setBackgroundColor(bg) end
  if fg then t.setTextColor(fg) end
  t.write(s)
end

local function bar(t, y, bg, w)
  t.setCursorPos(1, y)
  t.setBackgroundColor(bg)
  t.write(string.rep(" ", w))
end

local function center(t, w, y, s, fg, bg)
  s = cut(s, w)
  put(t, math.floor((w - #s) / 2) + 1, y, s, fg, bg)
end

local function addButton(list, x, y, w, action, h)
  list[#list + 1] = { x1 = x, y1 = y, x2 = x + w - 1, y2 = y + (h or 1) - 1, action = action }
end

local function btn(x, y, label, fg, bg, action)
  put(scr, x, y, label, fg, bg)
  addButton(UI.buttons, x, y, #label, action)
  return x + #label
end

local STATUS_INFO = {
  offline  = { "OFFLINE",  colors.gray },
  idle     = { "IDLE",     colors.lime },
  dialing  = { "DIALING",  colors.orange },
  engaging = { "ENGAGING", colors.orange },
  incoming = { "INCOMING", colors.red },
  open_out = { "OPEN",     colors.lightBlue },
  open_in  = { "INBOUND",  colors.red },
}

local function statusLabel()
  local s = STATUS_INFO[state.status] or STATUS_INFO.offline
  local label = s[1]
  if state.status == "dialing" or state.status == "incoming" then
    label = label .. " " .. tostring(state.chevrons or 0)
  end
  return label, s[2]
end

local function statusLong()
  local s = state.status
  if s == "open_out" then return "Open (outgoing)"
  elseif s == "open_in" then return "Open (INCOMING)"
  elseif s == "incoming" then return "Incoming connection"
  elseif s == "dialing" then return "Dialing"
  elseif s == "engaging" then return "Engaging"
  elseif s == "idle" then return "Idle"
  end
  return "Offline"
end

-- ---------------------------------------------------------------------
-- Gate renderer
-- ComputerCraft's drawing characters 128-159 split a cell into 2 x 3
-- square sub-pixels, so the gate is drawn at three times the detail of
-- plain cells. A cell can still only show two colours.
-- ---------------------------------------------------------------------

local atan2 = math.atan2 or math.atan
local TWO_PI = 2 * math.pi
local CHEVRON_STEP = TWO_PI / 9

-- Rough brightness of each colour. A third colour in a cell is merged into
-- whichever of the cell's two colours is closest.
local LUMA = {
  [colors.white] = 240, [colors.orange] = 183, [colors.magenta] = 168, [colors.lightBlue] = 178,
  [colors.yellow] = 209, [colors.lime] = 161, [colors.pink] = 200, [colors.gray] = 76,
  [colors.lightGray] = 153, [colors.cyan] = 133, [colors.purple] = 139, [colors.blue] = 98,
  [colors.brown] = 107, [colors.green] = 132, [colors.red] = 114, [colors.black] = 17,
}

local PIXEL_CHARS = {}
for code = 128, 159 do PIXEL_CHARS[code] = string.char(code) end

local function nearest(c, c1, c2)
  if c == c1 or c == c2 then return c end
  local l = LUMA[c] or 128
  if math.abs(l - (LUMA[c1] or 128)) <= math.abs(l - (LUMA[c2] or 128)) then return c1 end
  return c2
end

-- Packs six sub-pixels (top-left, top-right, middle-left, middle-right,
-- bottom-left, bottom-right) into one drawing character. The two colours
-- that matter most win; `prio` adds weight to colours that must not
-- vanish, such as lit chevrons.
local function packCell(p1, p2, p3, p4, p5, p6, prio)
  if p1 == p2 and p1 == p3 and p1 == p4 and p1 == p5 and p1 == p6 then
    return " ", p1, p1
  end
  local count = {}
  count[p1] = (count[p1] or 0) + 1
  count[p2] = (count[p2] or 0) + 1
  count[p3] = (count[p3] or 0) + 1
  count[p4] = (count[p4] or 0) + 1
  count[p5] = (count[p5] or 0) + 1
  count[p6] = (count[p6] or 0) + 1
  local c1, w1, c2, w2 = nil, -1, nil, -1
  for c, n in pairs(count) do
    local wgt = n + (prio[c] or 0)
    if wgt > w1 then
      c2, w2 = c1, w1
      c1, w1 = c, wgt
    elseif wgt > w2 then
      c2, w2 = c, wgt
    end
  end
  -- the bottom-right sub-pixel always shows the background colour
  local bg = nearest(p6, c1, c2)
  local fg = (bg == c1) and c2 or c1
  local code = 128
  if nearest(p1, c1, c2) == fg then code = code + 1 end
  if nearest(p2, c1, c2) == fg then code = code + 2 end
  if nearest(p3, c1, c2) == fg then code = code + 4 end
  if nearest(p4, c1, c2) == fg then code = code + 8 end
  if nearest(p5, c1, c2) == fg then code = code + 16 end
  return PIXEL_CHARS[code], fg, bg
end

-- Distance from the centre (1 = outer edge) and angle from the top
-- (clockwise) of every sub-pixel, cached per drawing size.
local GEOMETRY = {}
local function geometry(pw, ph)
  local key = pw * 1000 + ph
  local g = GEOMETRY[key]
  if g then return g end
  g = { d = {}, a = {}, R = math.min(pw, ph) / 2 }
  local cx, cy = (pw + 1) / 2, (ph + 1) / 2
  for y = 1, ph do
    for x = 1, pw do
      local dx, dy = x - cx, y - cy
      local i = (y - 1) * pw + x
      g.d[i] = math.sqrt(dx * dx + dy * dy) / g.R
      local a = atan2(dx, -dy)
      if a < 0 then a = a + TWO_PI end
      g.a[i] = a
    end
  end
  GEOMETRY[key] = g
  return g
end

-- Cheap repeatable noise in [0, 1) for glitter on the event horizon.
local function noise(x, y, f)
  local v = math.sin(x * 12.9898 + y * 78.233 + f * 37.719) * 43758.5453
  return v - math.floor(v)
end

-- Draws the gate into a w x h block of cells at (x0, y0) of terminal t:
-- body, symbol track (turning with the real ring), nine chevrons, and the
-- event horizon or iris in the middle.
local function drawRing(t, x0, y0, w, h, st, th)
  local pw, ph = w * 2, h * 3
  local g = geometry(pw, ph)
  local gd, ga, R = g.d, g.a, g.R
  local shape = GATE_SHAPE[st.gateKind or ""] or GATE_SHAPE.milky_way
  local frame = UI.frame or 0
  local open = st.status == "open_out" or st.status == "open_in"
  local kawoosh = UI.kawooshPhase
  local irisPct = (st.hasIris and st.irisName) and clamp(st.irisPct or 0, 0, 100) or 0
  local inner = shape.inner
  local irisEdge = inner * (1 - irisPct / 100)   -- the iris closes from the rim inwards
  local rot = math.rad(st.rotation or 0)
  local n = shape.glyphs or 0
  local sector = TWO_PI / math.max(1, n)
  local runner = nil
  if shape.stopMotion and n > 0 and (st.status == "dialing" or st.status == "incoming" or st.status == "engaging") then
    runner = (frame * 3) % n   -- Pegasus-style: a light runs round the symbols
  end
  local trackMid, trackHalf
  if shape.trackIn then
    trackMid = (shape.trackIn + shape.trackOut) / 2
    trackHalf = (shape.trackOut - shape.trackIn) * 0.3
  end
  local chevSize = shape.bigChevrons and 0.21 or 0.17
  local detail = R >= 20          -- big enough to show a light inside each chevron
  local lit = st.lit or {}
  local rimIn, rimOut = inner + 1.2 / R, 1 - 1.2 / R
  local core, mid = 0.18, 0.45
  if kawoosh then
    -- the kawoosh floods the horizon with light, then it settles
    local burst = math.sin(kawoosh * math.pi)
    core, mid = 0.18 + 0.8 * burst, 0.45 + 0.6 * burst
  end
  local sparkle = 1 - (th.sparkle or 0.03)
  local core2 = th.chevCore or th.chevOn

  local px = {}
  for y = 1, ph do
    for x = 1, pw do
      local i = (y - 1) * pw + x
      local d = gd[i]
      local c = colors.black
      if d <= 1 then
        local a = ga[i]
        if d >= inner then
          -- gate body, rims and symbol track
          if d >= rimOut or d <= rimIn then c = th.rim else c = th.ring end
          if trackMid and d >= shape.trackIn and d <= shape.trackOut then
            c = th.track
            if n > 0 then
              local s = ((a - rot) % TWO_PI) / sector
              local idx = math.floor(s)
              local f = s - idx
              if f > 0.28 and f < 0.72 and math.abs(d - trackMid) <= trackHalf then
                c = (runner == idx) and th.glyphLit or th.glyph
              end
            end
          end
          if shape.segments then
            local s = (a / CHEVRON_STEP + 0.5) % 1
            if s < 0.04 or s > 0.96 then c = th.rim end
          end
          -- chevrons, clockwise from the top one
          local k = math.floor(a / CHEVRON_STEP + 0.5) % 9
          local da = a - k * CHEVRON_STEP
          if da > math.pi then da = da - TWO_PI end
          local u = math.abs(da) * d      -- distance along the ring
          local v = 1 - d                 -- depth from the outer edge
          local on = lit[k]
          if shape.chevron == "v" then
            local size = chevSize * ((k == 0) and 1.2 or 1)
            local depth = size * 1.3
            if v <= depth and u <= size * (1 - v / depth) then
              c = on and th.chevOn or th.chevOff
              if on and detail then
                local iv = v - depth * 0.15
                local inDepth, inSize = depth * 0.7, size * 0.5
                if iv >= 0 and iv <= inDepth and u <= inSize * (1 - iv / inDepth) then c = core2 end
              end
            end
          else
            local size = shape.lightSize or 0.07
            if u <= size and math.abs(v - (1 - inner) / 2) <= size * 1.3 then
              c = on and th.chevOn or th.chevOff
            end
          end
        elseif irisPct > 0 and d >= irisEdge then
          local blade = math.floor((a + (d / inner) * 2.6) / (TWO_PI / 12)) % 2
          c = (blade == 0) and colors.gray or colors.lightGray
        elseif open or kawoosh then
          -- event horizon: bright core, moving ripples and glitter
          local dd = d / inner
          if dd < core then c = colors.white
          elseif dd < mid then c = th.horizon2
          else c = th.horizon end
          if dd >= core and (dd * 5 - frame * 0.4) % 1 < 0.12 then c = th.horizon2 end
          if noise(x, y, frame) > sparkle then c = colors.white end
        end
      end
      px[i] = c
    end
  end

  local prio = { [th.chevOn] = 2, [th.glyphLit] = 2, [core2] = 2 }
  for cy = 1, h do
    local chars, fgs, bgs = {}, {}, {}
    local r1 = (cy * 3 - 3) * pw
    local r2, r3 = r1 + pw, r1 + 2 * pw
    for cx = 1, w do
      local xl = cx * 2 - 1
      local ch, fg, bg = packCell(px[r1 + xl], px[r1 + xl + 1], px[r2 + xl], px[r2 + xl + 1],
        px[r3 + xl], px[r3 + xl + 1], prio)
      chars[cx], fgs[cx], bgs[cx] = ch, toBlit(fg), toBlit(bg)
    end
    t.setCursorPos(x0, y0 + cy - 1)
    t.blit(table.concat(chars), table.concat(fgs), table.concat(bgs))
  end
end

-- Address book helpers --------------------------------------------------

local function refilter()
  UI.filtered = {}
  local q = UI.search:lower()
  for i, e in ipairs(book) do
    local hay = (e.name .. " " .. (e.group or "") .. " " .. table.concat(e.address, "-")):lower()
    if q == "" or hay:find(q, 1, true) then UI.filtered[#UI.filtered + 1] = i end
  end
  UI.sel = clamp(UI.sel, 1, math.max(1, #UI.filtered))
end

local function selectedIndex()
  return UI.filtered[UI.sel]
end

local function selectedEntry()
  local i = selectedIndex()
  return i and book[i] or nil
end

local function entryValid(e)
  return validateAddress(e.address, state.maxSymbol or 47)
end

local function listLayout()
  local top = (W >= 40) and 2 or 3
  local listTop = (W >= 40) and (top + 2) or (top + 1)
  local listRows = H - listTop
  return listTop, listRows, math.max(1, math.floor(listRows / 2))
end

local function ensureVisible()
  local _, _, perPage = listLayout()
  if UI.sel <= UI.scroll then UI.scroll = UI.sel - 1 end
  if UI.sel > UI.scroll + perPage then UI.scroll = UI.sel - perPage end
  UI.scroll = clamp(UI.scroll, 0, math.max(0, #UI.filtered - perPage))
end

-- Modals ------------------------------------------------------------------

local function openDialog(title, text, buttons)
  UI.modal = { kind = "dialog", title = title, text = text, buttons = buttons }
end

local function openForm(title, fields, onSave)
  UI.modal = { kind = "form", title = title, fields = fields, focus = 1, onSave = onSave }
end

local function closeModal()
  UI.modal = nil
end

local function submitForm()
  local m = UI.modal
  local values = {}
  for i, f in ipairs(m.fields) do values[i] = f.value end
  local ok, err = m.onSave(values)
  if ok then closeModal() else m.err = err end
end

local function editEntry(index)
  local e = index and book[index] or nil
  openForm(e and "Edit address" or "New address", {
    { label = "Name", value = e and e.name or "" },
    { label = "Address, e.g. 26-6-14-31-11-29", value = e and table.concat(e.address, "-") or "" },
    { label = "Galaxy / note", value = e and e.group or "" },
  }, function(v)
    local addr = parseAddress(v[2])
    local ok, err = validateAddress(addr, 47)
    if not ok then return false, err end
    local name = trim(v[1])
    if name == "" then name = addressToString(addr) end
    local entry = { name = cut(name, 40), address = addr, group = cut(trim(v[3]), 40) }
    if index and book[index] then
      book[index] = entry
    else
      book[#book + 1] = entry
      UI.search = ""
      refilter()
      UI.sel = #UI.filtered
    end
    saveBook()
    refilter()
    ensureVisible()
    return true
  end)
end

local function deleteEntry(index)
  local e = book[index]
  if not e then return end
  openDialog("Delete address", "Remove '" .. e.name .. "' " .. addressToString(e.address) .. " from the address book?", {
    { label = " Delete ", color = colors.red, action = function()
      table.remove(book, index)
      saveBook()
      refilter()
      ensureVisible()
      closeModal()
    end },
    { label = " Keep ", color = colors.gray, action = closeModal },
  })
end

local function showHelp()
  openDialog("Help", table.concat({
    "Click an address to select it, click it again (or press Enter) to dial.",
    "Type to search. Arrows move the selection, Tab changes page.",
    "[+] adds, [-] removes, [Edit] changes the selected address. The arrows on the right reorder the list.",
    "Green bar: this gate can dial it. Red: a symbol is out of range for this gate.",
    "Hold Ctrl+T to quit.",
  }, "\n"), { { label = " OK ", color = colors.gray, action = closeModal } })
end

local function dialSelected()
  local e = selectedEntry()
  if not e then return end
  local ok, err = entryValid(e)
  if not ok then
    log("err", e.name .. ": " .. err)
    return
  end
  Controller.dial(e)
end

local function moveEntry(index, delta)
  local j = index + delta
  if UI.search ~= "" or j < 1 or j > #book then return end
  book[index], book[j] = book[j], book[index]
  saveBook()
  refilter()
  UI.sel = j
  ensureVisible()
end

local function isBusy()
  local s = state.status
  return s == "dialing" or s == "engaging" or s == "open_out" or s == "open_in" or s == "incoming"
end

-- Header ------------------------------------------------------------------

local TABS = {
  { id = "book", long = "Dialer", short = "Dial" },
  { id = "gate", long = "Gate",   short = "Gate" },
  { id = "log",  long = "Log",    short = "Log" },
  { id = "cfg",  long = "Config", short = "Cfg" },
}

local function drawHeader()
  local th = theme()
  local wide = W >= 40
  local longTabs = W >= 46
  bar(scr, 1, colors.gray, W)
  local x = 1
  if wide then
    local title = (W >= 57) and " SG HYBRID LEGACY " or " SGHL "
    put(scr, 1, 1, title, colors.black, th.accent)
    x = #title + 1
  end
  for _, tab in ipairs(TABS) do
    local label = " " .. (longTabs and tab.long or tab.short) .. " "
    local active = UI.view == tab.id
    x = btn(x, 1, label, active and colors.black or colors.white, active and colors.lightGray or colors.gray, function()
      UI.view = tab.id
    end)
  end
  local label, col = statusLabel()
  if wide then
    label = " " .. label .. " "
    put(scr, W - #label + 1, 1, label, colors.black, col)
  else
    bar(scr, 2, colors.black, W)
    put(scr, 1, 2, " " .. label .. " ", colors.black, col)
    local info = state.target and state.target.name or (state.status == "offline" and "" or state.gateLabel)
    if state.status == "open_out" or state.status == "open_in" then
      info = formatDuration(state.openSeconds) .. " " .. (info or "")
    end
    put(scr, #label + 4, 2, cut(info or "", W - #label - 3), colors.lightGray, colors.black)
  end
end

-- Dialer page ---------------------------------------------------------------

local function drawBook()
  local wide = W >= 40
  local top = wide and 2 or 3
  local listTop, listRows, perPage = listLayout()
  refilter()
  ensureVisible()

  -- count + local address
  if wide then
    put(scr, 1, top, "Addresses: (" .. #book .. ")", colors.white, colors.black)
    local here = state.localAddress and addressToString(state.localAddress) or (state.gateLabel ~= "-" and (state.gateLabel .. " gate") or "")
    if MODE == "remote" then here = state.host and ("Host " .. state.host) or "No host" end
    here = cut(here, W - 17)
    put(scr, W - #here + 1, top, here, colors.lightBlue, colors.black)
  end

  -- search box
  local sy = wide and (top + 1) or top
  local label = wide and "Search: " or "Find:"
  put(scr, 1, sy, label, colors.white, colors.black)
  local fx = #label + 1
  local fw = W - fx - (wide and 2 or 4)
  put(scr, fx, sy, fit(UI.search, fw), colors.black, colors.lightGray)
  UI.cursor = { x = fx + math.min(#UI.search, fw - 1), y = sy, color = colors.black }
  btn(fx + fw, sy, "x", colors.white, colors.red, function()
    UI.search = ""
    refilter()
  end)
  if not wide then put(scr, fx + fw + 1, sy, fit(tostring(#book), 3), colors.lightGray, colors.black) end

  -- list
  local contentW = wide and (W - 3) or (W - 1)
  if #UI.filtered == 0 then
    put(scr, 2, listTop + 1, (#book == 0) and "The address book is empty. Use [+]." or "No match.", colors.gray, colors.black)
  end
  for slot = 1, perPage do
    local fi = UI.scroll + slot
    local bi = UI.filtered[fi]
    local y = listTop + (slot - 1) * 2
    if bi then
      local e = book[bi]
      local selected = fi == UI.sel
      local bg = selected and colors.gray or colors.black
      local ok = entryValid(e)
      put(scr, 1, y, fit(cut(" " .. e.name, wide and (contentW - 1) or contentW), contentW), selected and colors.white or colors.lightGray, bg)
      local line = " " .. table.concat(e.address, "-")
      local textW = wide and (contentW - 1) or contentW
      put(scr, 1, y + 1, fit(cut(line, textW), contentW), colors.lightBlue, bg)
      local x = #line + 2
      if config.showGlyphs and x < textW then
        local g = cut(glyphString(e.address), textW - x + 1)
        put(scr, x, y + 1, g, colors.cyan, bg)
        x = x + #g + 1
      end
      if e.group ~= "" and x + 2 < textW then
        put(scr, x, y + 1, cut("- " .. e.group, textW - x + 1), selected and colors.lightGray or colors.gray, bg)
      end
      addButton(UI.buttons, 1, y, contentW, function()
        if UI.sel == fi then
          dialSelected()
        else
          UI.sel = fi
        end
      end, 2)
      if wide then
        local canMove = UI.search == ""
        btn(W - 2, y, "\30", canMove and colors.white or colors.gray, colors.black, function() moveEntry(bi, -1) end)
        btn(W - 2, y + 1, "\31", canMove and colors.white or colors.gray, colors.black, function() moveEntry(bi, 1) end)
      end
      local barColor = colors.gray
      if state.dialMethod then barColor = ok and colors.lime or colors.red end
      put(scr, W, y, " ", nil, barColor)
      put(scr, W, y + 1, " ", nil, barColor)
    end
  end

  -- buttons
  bar(scr, H, colors.gray, W)
  local x = 1
  x = btn(x, H, "[+]", colors.white, colors.gray, function() editEntry(nil) end)
  x = btn(x, H, "[-]", colors.white, colors.gray, function()
    local i = selectedIndex()
    if i then deleteEntry(i) end
  end)
  if wide then
    x = btn(x, H, "[Edit]", colors.white, colors.gray, function()
      local i = selectedIndex()
      if i then editEntry(i) end
    end)
    x = btn(x, H, "[?]", colors.white, colors.gray, showHelp)
    if MODE == "host" then
      x = btn(x + 1, H, (config.autoClose and "[x]" or "[ ]") .. " Auto Close", colors.white, colors.gray, function()
        config.autoClose = not config.autoClose
        saveConfig()
      end)
    end
  else
    x = btn(x, H, "[E]", colors.white, colors.gray, function()
      local i = selectedIndex()
      if i then editEntry(i) end
    end)
  end
  local closeLabel = " Close "
  local dialLabel = (state.status == "dialing" and MODE == "host") and " Abort " or " Dial "
  local cx = W - #closeLabel + 1
  btn(cx, H, closeLabel, colors.white, colors.red, function() Controller.close() end)
  btn(cx - #dialLabel - 1, H, dialLabel, colors.black, colors.lime, function()
    if dialLabel == " Abort " then Controller.close() else dialSelected() end
  end)
end

-- Gate page -----------------------------------------------------------------

local SHORT_LABEL = {
  Interface = "Iface", Address = "Addr", Chevrons = "Chev", ["Open for"] = "Open",
  Energy = "Power", Feedback = "Info", Remote = "From", Dialed = "Dial",
}

local function infoLines(width, labelW)
  local lines = {}
  local function add(label, value, color)
    if labelW < 9 then label = SHORT_LABEL[label] or label end
    lines[#lines + 1] = { label, tostring(value or "-"), color or colors.white }
  end
  add("Gate", state.gateLabel .. ((state.gateKind and state.gateKind ~= "unknown") and (" (" .. theme().name .. ")") or ""))
  if MODE == "remote" then
    add("Host", state.host or "-")
  else
    add("Interface", state.tier .. (state.interfaceName and (" @" .. state.interfaceName) or ""))
  end
  local _, scol = statusLabel()
  add("Status", statusLong(), scol)
  if state.localAddress then add("Local", addressToString(state.localAddress), colors.lightBlue) end
  if state.target then
    add("Target", state.target.name, colors.yellow)
    add("Address", addressToString(state.target.address), colors.lightBlue)
  elseif state.remoteAddress then
    add("Remote", addressToString(state.remoteAddress), colors.lightBlue)
  elseif state.dialedAddress and #state.dialedAddress > 0 then
    add("Dialed", addressToString(state.dialedAddress), colors.lightBlue)
  end
  add("Chevrons", tostring(state.chevrons or 0))
  if state.status == "open_out" or state.status == "open_in" then
    add("Open for", formatDuration(state.openSeconds))
  end
  if state.energy then add("Energy", formatNumber(state.energy) .. " FE") end
  if state.hasIris then
    if state.irisName then
      local pos = (state.irisPct >= 100) and "CLOSED" or ((state.irisPct <= 0) and "Open" or ("Moving " .. state.irisPct .. "%"))
      add("Iris", pos, (state.irisPct >= 100) and colors.orange or colors.white)
      add("", state.irisName, colors.gray)
    else
      add("Iris", "none installed", colors.gray)
    end
  end
  add("Feedback", state.feedbackText or "-", (state.feedbackCode and state.feedbackCode < 0) and colors.red or colors.lightGray)
  if state.problem and state.status ~= "offline" then add("Note", state.problem, colors.orange) end
  -- wrap long values
  local out = {}
  for _, l in ipairs(lines) do
    local parts = wrap(l[2], math.max(4, width - labelW - 1))
    for i, p in ipairs(parts) do
      out[#out + 1] = { i == 1 and l[1] or "", p, l[3] }
    end
  end
  return out
end

local function drawGate()
  local wide = W >= 40
  local top = wide and 2 or 3
  local th = theme()
  local ringX, ringY, ringW, ringH, infoX, infoY, infoW
  if wide then
    ringH = math.min(H - top - 4, 11)
    ringW = math.floor(ringH * 1.5)
    if ringW % 2 == 0 then ringW = ringW + 1 end
    ringX, ringY = 2, top + 1
    infoX, infoY = ringX + ringW + 2, top + 1
    infoW = W - infoX + 1
  else
    ringH = math.min(7, H - 12)
    ringW = math.floor(ringH * 1.5)
    if ringW % 2 == 0 then ringW = ringW + 1 end
    ringX, ringY = math.floor((W - ringW) / 2) + 1, top + 1
    infoX, infoY = 1, ringY + ringH + 1
    infoW = W
  end

  if state.status == "offline" and state.problem then
    local lines = wrap(state.problem, W - 4)
    for i, l in ipairs(lines) do put(scr, 3, top + 1 + i, l, colors.orange, colors.black) end
    if MODE == "host" then
      btn(3, top + #lines + 3, " Search again ", colors.white, colors.gray, function()
        Gate.detect()
        redraw()
      end)
    end
    return
  end

  drawRing(scr, ringX, ringY, ringW, ringH, state, th)
  if wide and state.target then
    local g = config.showGlyphs and glyphString(state.target.address) or ""
    center(scr, ringW + 2, ringY + ringH, g, colors.cyan, colors.black)
  end

  local labelW = wide and 9 or 6
  local lines = infoLines(infoW, labelW)
  local maxLines = H - infoY
  for i = 1, math.min(#lines, maxLines) do
    local l = lines[i]
    put(scr, infoX, infoY + i - 1, fit(l[1], labelW), colors.gray, colors.black)
    put(scr, infoX + labelW + 1, infoY + i - 1, cut(l[2], infoW - labelW - 1), l[3], colors.black)
  end

  bar(scr, H, colors.gray, W)
  local x = 1
  local busy = state.status == "dialing" and MODE == "host"
  x = btn(x, H, busy and " Abort " or (wide and " Close Gate " or " Close "), colors.white, colors.red, function() Controller.close() end) + 1
  if state.hasIris and state.irisName then
    local irisLabel = ((state.irisPct or 0) >= 50) and " Open Iris " or " Close Iris "
    if not wide then irisLabel = " Iris " end
    x = btn(x, H, irisLabel, colors.black, colors.lightGray, function() Controller.iris("toggle") end) + 1
  end
  if MODE == "host" and wide then
    btn(x, H, " Rescan ", colors.black, colors.lightGray, function()
      Gate.detect()
      log("info", "Rescanned peripherals")
    end)
  end
end

-- Log page ------------------------------------------------------------------

local LOG_COLORS = {
  info = colors.lightGray, ok = colors.lime, warn = colors.orange,
  err = colors.red, travel = colors.lightBlue,
}

local function drawLog()
  local top = (W >= 40) and 2 or 3
  local rows = {}
  for _, l in ipairs(logLines) do
    local stamp = "[" .. l.t .. "] "
    local parts = wrap(l.msg, W - #stamp)
    for i, p in ipairs(parts) do
      rows[#rows + 1] = { (i == 1) and stamp or string.rep(" ", #stamp), p, LOG_COLORS[l.kind] or colors.white }
    end
  end
  local visible = H - top + 1
  UI.logScroll = clamp(UI.logScroll, 0, math.max(0, #rows - visible))
  if #rows == 0 then put(scr, 2, top + 1, "Nothing logged yet.", colors.gray, colors.black) end
  for i = 1, visible do
    local r = rows[i + UI.logScroll]
    if r then
      put(scr, 1, top + i - 1, r[1], colors.gray, colors.black)
      put(scr, #r[1] + 1, top + i - 1, r[2], r[3], colors.black)
    end
  end
end

-- Config page ---------------------------------------------------------------

local CONFIG_ITEMS = {
  { key = "autoClose",      label = "Auto Close after travel",      short = "Auto Close",     kind = "bool", host = true },
  { key = "autoCloseDelay", label = "Auto Close delay (s)",         short = "Close delay",    kind = "num", min = 0, max = 120, step = 1, host = true },
  { key = "maxOpenSeconds", label = "Seconds to stay open (0=off)", short = "Max open s",     kind = "num", min = 0, max = 2280, step = 10, host = true },
  { key = "irisOnIncoming", label = "Close iris on incoming",       short = "Iris incoming",  kind = "bool", host = true },
  { key = "restoreIris",    label = "Return to previous iris",      short = "Restore iris",   kind = "bool", host = true },
  { key = "sgcStyle",       label = "SGC 3-step chevrons",          short = "SGC 3-step",     kind = "bool", host = true },
  { key = "stepDelay",      label = "Ring dialing delay (s)",       short = "Ring delay",     kind = "num", min = 0, max = 3, step = 0.5, host = true },
  { key = "directEngage",   label = "Instant dial (Adv. Crystal)",  short = "Instant dial",   kind = "bool", host = true },
  { key = "showGlyphs",     label = "Show glyph marks",             short = "Glyph marks",    kind = "bool" },
  { key = "theme",          label = "Gate style",                   short = "Style",          kind = "choice", choices = THEME_ORDER },
  { key = "monitorBoard",   label = "Monitor status board",         short = "Monitor board",  kind = "bool", host = true },
  { key = "remoteEnabled",  label = "Allow pocket dialers",         short = "Pocket dialers", kind = "bool", host = true },
  { key = "remoteHost",     label = "Dialing computer name",        short = "Host name",      kind = "text", remote = true },
  { key = "remotePassword", label = "Pocket dialer password",       short = "Password",       kind = "text" },
}

local Board

local function drawConfig()
  local top = (W >= 40) and 2 or 3
  local rows = {}
  local function row(fn) rows[#rows + 1] = fn end

  row(function(y) put(scr, 1, y, "Configurator", theme().accent, colors.black) end)
  for _, item in ipairs(CONFIG_ITEMS) do
    local show = not ((item.host and MODE ~= "host") or (item.remote and MODE ~= "remote"))
    if show then
      row(function(y)
        local v = config[item.key]
        local itemLabel = (W >= 40) and item.label or item.short
        if item.kind == "bool" then
          btn(2, y, (v and "[x] " or "[ ] ") .. itemLabel, v and colors.white or colors.lightGray, colors.black, function()
            config[item.key] = not config[item.key]
            saveConfig()
            if item.key == "monitorBoard" and Board then Board.refresh() end
          end)
        elseif item.kind == "num" then
          put(scr, 2, y, cut(itemLabel, W - 14), colors.lightGray, colors.black)
          local x = W - 11
          btn(x, y, "[-]", colors.white, colors.gray, function()
            config[item.key] = clamp(config[item.key] - item.step, item.min, item.max)
            saveConfig()
          end)
          put(scr, x + 3, y, fit(" " .. tostring(v), 5), colors.yellow, colors.black)
          btn(x + 8, y, "[+]", colors.white, colors.gray, function()
            config[item.key] = clamp(config[item.key] + item.step, item.min, item.max)
            saveConfig()
          end)
        elseif item.kind == "choice" then
          put(scr, 2, y, itemLabel, colors.lightGray, colors.black)
          local shown = (v == "auto") and ("Auto (" .. theme().name .. ")") or (THEMES[v] and THEMES[v].name or v)
          local label = "< " .. shown .. " >"
          btn(W - #label, y, label, colors.yellow, colors.black, function()
            local idx = 1
            for i, c in ipairs(item.choices) do if c == config[item.key] then idx = i end end
            config[item.key] = item.choices[idx % #item.choices + 1]
            saveConfig()
          end)
        elseif item.kind == "text" then
          put(scr, 2, y, cut(itemLabel, W - 14), colors.lightGray, colors.black)
          local shown = (v == "") and "(none)" or ((item.key == "remotePassword") and string.rep("*", #v) or v)
          local label = "[" .. cut(shown, 10) .. "]"
          btn(W - #label, y, label, colors.yellow, colors.black, function()
            openForm(item.label, { { label = item.label, value = config[item.key] } }, function(vals)
              config[item.key] = trim(vals[1])
              saveConfig()
              return true
            end)
          end)
        end
      end)
    end
  end

  if MODE == "host" and state.hasFilter then
    row(function() end)
    row(function(y) put(scr, 1, y, "Gate address access list", theme().accent, colors.black) end)
    row(function(y)
      local x = 2
      local ft = state.filterType or 0
      for _, opt in ipairs({ { 0, "Off" }, { 1, "Whitelist" }, { -1, "Blacklist" } }) do
        local on = ft == opt[1]
        x = btn(x, y, (on and "(o) " or "( ) ") .. opt[2], on and colors.white or colors.lightGray, colors.black, function()
          Gate.setFilter(opt[1])
        end) + 1
      end
    end)
    row(function(y)
      local e = selectedEntry()
      local x = btn(2, y, "[Add selected]", colors.white, colors.gray, function() Gate.filterAdd(selectedEntry()) end)
      x = btn(x + 1, y, "[Clear]", colors.white, colors.gray, function() Gate.filterClear() end)
      if e then put(scr, x + 1, y, cut(e.name, W - x - 1), colors.gray, colors.black) end
    end)
  end

  row(function() end)
  row(function(y)
    local x = 2
    if MODE == "host" then
      x = btn(x, y, "[Rescan]", colors.white, colors.gray, function()
        Gate.detect()
        if Board then Board.refresh() end
        log("info", "Rescanned peripherals")
      end) + 1
    end
    x = btn(x, y, "[Reset book]", colors.white, colors.gray, function()
      openDialog("Reset address book", "Replace the address book with the built-in Stargate Journey addresses?", {
        { label = " Reset ", color = colors.red, action = function()
          book = copy(DEFAULT_BOOK)
          saveBook()
          UI.search = ""
          refilter()
          closeModal()
        end },
        { label = " Cancel ", color = colors.gray, action = closeModal },
      })
    end) + 1
    btn(x, y, "[Quit]", colors.white, colors.red, function() UI.quit = true end)
  end)
  row(function(y) put(scr, 2, y, cut("SGHL v" .. VERSION .. " " .. (MODE == "host" and "dialing computer" or "pocket dialer"), W - 2), colors.gray, colors.black) end)

  local visible = H - top + 1
  UI.cfgScroll = clamp(UI.cfgScroll, 0, math.max(0, #rows - visible))
  for i = 1, visible do
    local fn = rows[i + UI.cfgScroll]
    if fn then fn(top + i - 1) end
  end
  if #rows > visible then
    put(scr, W, top, "\30", colors.gray, colors.black)
    put(scr, W, H, "\31", colors.gray, colors.black)
  end
end

-- Modal drawing -------------------------------------------------------------

local function drawModal()
  local m = UI.modal
  if not m then return end
  local th = theme()
  local mw = math.min(W - 2, 44)
  local inner = mw - 2
  local body = {}
  if m.kind == "dialog" then
    for _, l in ipairs(wrap(m.text, inner)) do body[#body + 1] = { text = l } end
  else
    for i, f in ipairs(m.fields) do
      body[#body + 1] = { text = cut(f.label, inner) }
      body[#body + 1] = { field = i }
    end
    body[#body + 1] = { text = m.err or "", color = colors.red }
  end
  local mh = #body + 3
  local x0 = math.floor((W - mw) / 2) + 1
  local y0 = math.max(1, math.floor((H - mh) / 2) + 1)
  put(scr, x0, y0, fit(" " .. m.title, mw), colors.black, th.accent)
  for i = 1, mh - 1 do put(scr, x0, y0 + i, string.rep(" ", mw), nil, colors.lightGray) end
  UI.cursor = nil
  for i, b in ipairs(body) do
    local y = y0 + i
    if b.field then
      local f = m.fields[b.field]
      local focused = m.focus == b.field
      local shown = f.value
      if #shown > inner - 1 then shown = shown:sub(#shown - inner + 2) end
      put(scr, x0 + 1, y, fit(shown, inner), colors.white, focused and colors.black or colors.gray)
      addButton(UI.buttons, x0 + 1, y, inner, function() m.focus = b.field end)
      if focused then UI.cursor = { x = x0 + 1 + math.min(#shown, inner - 1), y = y, color = colors.white } end
    else
      put(scr, x0 + 1, y, cut(b.text, inner), b.color or colors.black, colors.lightGray)
    end
  end
  local by = y0 + mh - 1
  local buttons = m.buttons
  if m.kind == "form" then
    buttons = {
      { label = " Save ", color = colors.green, action = submitForm },
      { label = " Cancel ", color = colors.gray, action = closeModal },
    }
  end
  local x = x0 + mw - 1
  for i = #buttons, 1, -1 do
    local b = buttons[i]
    x = x - #b.label
    btn(x, by, b.label, colors.white, b.color or colors.gray, b.action)
    x = x - 1
  end
end

-- Monitor status board --------------------------------------------------------

Board = { mon = nil, win = nil, name = nil }

function Board.refresh()
  Board.mon, Board.win, Board.name = nil, nil, nil
  if MODE ~= "host" or not config.monitorBoard then return end
  local mon = peripheral.find("monitor")
  if not mon then return end
  pcall(mon.setTextScale, config.monitorScale)
  local mw, mh = mon.getSize()
  Board.mon = mon
  Board.name = peripheral.getName(mon)
  Board.win = window.create(mon, 1, 1, mw, mh, true)
end

function Board.draw()
  local t = Board.win
  UI.monButtons = {}
  if not t then return end
  local mw, mh = t.getSize()
  local th = theme()
  t.setVisible(false)
  t.setBackgroundColor(colors.black)
  t.clear()
  if mw < 15 or mh < 10 then
    put(t, 1, 1, "Monitor too", colors.white, colors.black)
    put(t, 1, 2, "small", colors.white, colors.black)
    t.setVisible(true)
    return
  end
  bar(t, 1, colors.gray, mw)
  put(t, 2, 1, cut(state.gateLabel .. " Stargate", mw - 12), colors.white, colors.gray)
  local label, col = statusLabel()
  label = " " .. label .. " "
  put(t, mw - #label + 1, 1, label, colors.black, col)

  local rh = mh - 6
  local rw = math.floor(rh * 1.5)
  if rw % 2 == 0 then rw = rw + 1 end
  if rw > mw - 2 then
    rw = mw - 2
    if rw % 2 == 0 then rw = rw - 1 end
    rh = math.max(5, math.floor(rw / 1.5))
  end
  if state.status == "offline" then
    local lines = wrap(state.problem or "Offline", mw - 2)
    for i, l in ipairs(lines) do put(t, 2, 2 + i, l, colors.orange, colors.black) end
  else
    drawRing(t, math.floor((mw - rw) / 2) + 1, 2, rw, rh, state, th)
  end

  local y = rh + 3
  local name = state.target and state.target.name
  if not name then
    if state.status == "open_in" or state.status == "incoming" then name = "INCOMING WORMHOLE"
    else name = statusLong() end
  end
  center(t, mw, y, name, (state.status == "open_in" or state.status == "incoming") and colors.red or colors.yellow, colors.black)
  local addr = state.target and state.target.address or state.remoteAddress or state.dialedAddress
  if addr and #addr > 0 then center(t, mw, y + 1, addressToString(addr), colors.lightBlue, colors.black) end
  local fb = state.feedbackText or ""
  if state.status == "open_out" or state.status == "open_in" then
    fb = "Open " .. formatDuration(state.openSeconds)
  elseif state.status == "incoming" or state.status == "dialing" then
    fb = "Chevron " .. tostring(state.chevrons or 0) .. " locked"
  end
  center(t, mw, y + 2, fb, colors.lightGray, colors.black)

  local b1 = (state.status == "dialing") and " ABORT " or " CLOSE "
  local b2 = (state.hasIris and state.irisName) and " IRIS " or nil
  local total = #b1 + (b2 and (#b2 + 2) or 0)
  local x = math.floor((mw - total) / 2) + 1
  put(t, x, mh, b1, colors.white, colors.red)
  addButton(UI.monButtons, x, mh, #b1, function() Controller.close() end)
  if b2 then
    local x2 = x + #b1 + 2
    put(t, x2, mh, b2, colors.black, colors.lightGray)
    addButton(UI.monButtons, x2, mh, #b2, function() Controller.iris("toggle") end)
  end
  t.setVisible(true)
end

-- Main draw -------------------------------------------------------------------

-- Starts the kawoosh when a wormhole opens while we are watching (not when
-- the program starts up next to a gate that is already open).
local function updateAnimation()
  local s = state.status
  local isOpen = s == "open_out" or s == "open_in"
  local was = UI.lastStatus
  if isOpen and was and was ~= "offline" and was ~= "open_out" and was ~= "open_in" then
    UI.kawooshStart = os.clock()
  end
  if not isOpen then UI.kawooshStart = nil end
  UI.lastStatus = s
  UI.kawooshPhase = nil
  if UI.kawooshStart then
    local p = (os.clock() - UI.kawooshStart) / 1.5
    if p < 1 then UI.kawooshPhase = p else UI.kawooshStart = nil end
  end
end

-- True while something on a visible gate moves.
local function wantsAnimation()
  if UI.view ~= "gate" and not Board.win then return false end
  local s = state.status
  if s == "open_out" or s == "open_in" or s == "dialing" or s == "incoming" or s == "engaging" then return true end
  if UI.kawooshStart then return true end
  local p = state.irisPct or 0
  return state.irisName ~= nil and p > 0 and p < 100
end

local function draw()
  updateAnimation()
  UI.buttons = {}
  UI.cursor = nil
  scr.setVisible(false)
  scr.setBackgroundColor(colors.black)
  scr.clear()
  drawHeader()
  if UI.view == "book" then drawBook()
  elseif UI.view == "gate" then drawGate()
  elseif UI.view == "log" then drawLog()
  else drawConfig() end
  if UI.view ~= "book" then UI.cursor = nil end
  if UI.modal then
    UI.buttons = {}
    drawModal()
  end
  if UI.cursor then
    scr.setCursorPos(UI.cursor.x, UI.cursor.y)
    scr.setTextColor(UI.cursor.color or colors.white)
    scr.setCursorBlink(true)
  else
    scr.setCursorBlink(false)
  end
  scr.setVisible(true)
  if Board.win then
    local ok = pcall(Board.draw)
    if not ok then Board.refresh() end
  end
end

-- =====================================================================
-- Input
-- =====================================================================

local function hit(list, x, y)
  for i = #list, 1, -1 do
    local b = list[i]
    if x >= b.x1 and x <= b.x2 and y >= b.y1 and y <= b.y2 then
      b.action()
      return true
    end
  end
  return false
end

local function cycleView(delta)
  local idx = 1
  for i, t in ipairs(TABS) do if t.id == UI.view then idx = i end end
  idx = (idx - 1 + delta) % #TABS + 1
  UI.view = TABS[idx].id
end

local function onKey(k)
  local m = UI.modal
  if m then
    if m.kind == "form" then
      local f = m.fields[m.focus]
      if k == keys.enter then
        if m.focus < #m.fields then m.focus = m.focus + 1 else submitForm() end
      elseif k == keys.tab or k == keys.down then
        m.focus = m.focus % #m.fields + 1
      elseif k == keys.up then
        m.focus = (m.focus - 2) % #m.fields + 1
      elseif k == keys.backspace then
        f.value = f.value:sub(1, -2)
      end
    elseif k == keys.enter then
      m.buttons[1].action()
    end
    return
  end
  if k == keys.tab then
    cycleView(1)
    return
  end
  if UI.view == "book" then
    if k == keys.up then UI.sel = math.max(1, UI.sel - 1)
    elseif k == keys.down then UI.sel = math.min(#UI.filtered, UI.sel + 1)
    elseif k == keys.pageUp then UI.sel = math.max(1, UI.sel - 5)
    elseif k == keys.pageDown then UI.sel = math.min(#UI.filtered, UI.sel + 5)
    elseif k == keys.home then UI.sel = 1
    elseif k == keys["end"] then UI.sel = #UI.filtered
    elseif k == keys.enter then dialSelected()
    elseif k == keys.backspace then
      UI.search = UI.search:sub(1, -2)
      refilter()
    elseif k == keys.delete then
      local i = selectedIndex()
      if i then deleteEntry(i) end
    elseif k == keys.insert then
      editEntry(nil)
    end
    UI.sel = math.max(1, UI.sel)
    ensureVisible()
  elseif UI.view == "log" then
    if k == keys.up then UI.logScroll = UI.logScroll - 1
    elseif k == keys.down then UI.logScroll = UI.logScroll + 1 end
  elseif UI.view == "cfg" then
    if k == keys.up then UI.cfgScroll = UI.cfgScroll - 1
    elseif k == keys.down then UI.cfgScroll = UI.cfgScroll + 1 end
  end
end

local function onChar(c)
  local m = UI.modal
  if m then
    if m.kind == "form" then
      local f = m.fields[m.focus]
      if #f.value < 60 then f.value = f.value .. c end
    end
    return
  end
  if UI.view == "book" then
    if #UI.search < 30 then UI.search = UI.search .. c end
    UI.sel = 1
    UI.scroll = 0
    refilter()
  elseif UI.view == "gate" then
    if c == "c" then Controller.close()
    elseif c == "i" then Controller.iris("toggle") end
  end
end

local function onScroll(dir)
  if UI.modal then return end
  if UI.view == "book" then
    local _, _, perPage = listLayout()
    UI.scroll = clamp(UI.scroll + dir, 0, math.max(0, #UI.filtered - perPage))
  elseif UI.view == "log" then
    UI.logScroll = UI.logScroll + dir
  elseif UI.view == "cfg" then
    UI.cfgScroll = UI.cfgScroll + dir
  end
end

local function uiLoop()
  refilter()
  Board.refresh()
  draw()
  while true do
    local ev = { os.pullEventRaw() }
    local e = ev[1]
    local dirty = true
    if e == "terminate" then
      return
    elseif e == "mouse_click" then
      hit(UI.buttons, ev[3], ev[4])
    elseif e == "mouse_scroll" then
      onScroll(ev[2])
    elseif e == "monitor_touch" then
      if Board.name and ev[2] == Board.name then hit(UI.monButtons, ev[3], ev[4]) end
    elseif e == "char" then
      onChar(ev[2])
    elseif e == "paste" then
      for c in tostring(ev[2]):gmatch(".") do onChar(c) end
    elseif e == "key" then
      onKey(ev[2])
    elseif e == "term_resize" then
      W, H = native.getSize()
      scr.reposition(1, 1, W, H)
    elseif e == "monitor_resize" or e == "peripheral" or e == "peripheral_detach" then
      Board.refresh()
    elseif e == "timer" and ev[2] == UI.animTimer then
      UI.animTimer = nil
      UI.frame = UI.frame + 1
    elseif e ~= "sghl_redraw" then
      dirty = false
    end
    if UI.quit then return end
    if dirty then draw() end
    if not UI.animTimer and wantsAnimation() then
      UI.animTimer = os.startTimer(0.25)
    end
  end
end

-- =====================================================================
-- Start
-- =====================================================================

local tasks = { uiLoop }
if MODE == "host" then
  log("info", "SGHL v" .. VERSION .. " started")
  tasks[#tasks + 1] = gateLoop
  tasks[#tasks + 1] = dialWorker
  tasks[#tasks + 1] = hostRemoteLoop
else
  state.problem = "Searching for a dialing computer..."
  log("info", "Pocket dialer v" .. VERSION .. " started")
  tasks[#tasks + 1] = remoteClientLoop
end

local ok, err = pcall(parallel.waitForAny, unpack(tasks))

scr.setVisible(true)
native.setBackgroundColor(colors.black)
native.setTextColor(colors.white)
native.clear()
native.setCursorPos(1, 1)
if Board.win then
  pcall(function()
    Board.win.setBackgroundColor(colors.black)
    Board.win.clear()
  end)
end
if not ok and err ~= "Terminated" then
  printError(tostring(err))
end
print("Stargate Hybrid Legacy closed.")
