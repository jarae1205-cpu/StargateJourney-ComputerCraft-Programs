--
-- sgc.book - the shared address book
--
-- Same file and format as the Personal Dialer (dialer_addresses.db), so the
-- gate room, the hub and the dialer can share one list of gates.
--
-- entry = {
--   name    = "Abydos",
--   address = { 26, 6, 14, 31, 11, 29 } (Stargate Journey, Lantea), "WLDQDQBMT" (SGCraft),
--             { "Crater", "Virgo", ... } (Just Stargate Mod) or nil (planned, no address yet),
--   note    = "free text",
--   group   = "Milky Way",   -- hub tab
--   color   = "blue",        -- hub portal colour, a key of the colors API
--   last    = "ok" | "fail" | nil,
-- }
--

local A = require("sgc.address")

local B = {}
B.__index = B

B.DEFAULT_FILE = "dialer_addresses.db"

B.DEFAULTS = {
    { name = "Abydos", address = { 26, 6, 14, 31, 11, 29 },    note = "Milky Way", group = "Milky Way", color = "blue" },
    { name = "Chulak", address = { 8, 1, 22, 14, 36, 19 },     note = "Milky Way", group = "Milky Way", color = "lightBlue" },
    { name = "Lantea", address = { 18, 20, 1, 15, 14, 7, 19 }, note = "Pegasus",   group = "Pegasus",   color = "cyan" },
}

local function trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function B.clean(e)
    if type(e) ~= "table" then return nil end
    local address = A.fromValue(e.address)
    local name = trim(e.name)
    if not address and name == "" then return nil end
    local color = type(e.color) == "string" and colors[e.color] and e.color or nil
    return {
        name = name ~= "" and name or A.format(address),
        address = address,
        note = trim(e.note),
        group = trim(e.group) ~= "" and trim(e.group) or nil,
        color = color,
        last = (e.last == "ok" or e.last == "fail") and e.last or nil,
    }
end

-- opens (and if needed creates) the address book
function B.open(path)
    local self = setmetatable({ path = path or B.DEFAULT_FILE, entries = {}, settings = {}, notice = nil }, B)
    self:reload(true)
    return self
end

function B:reload(firstLoad)
    local entries, settings = {}, {}
    if fs.exists(self.path) then
        local f = fs.open(self.path, "r")
        local data = f and textutils.unserialize(f.readAll())
        if f then f.close() end
        if type(data) == "table" then
            for _, e in ipairs(type(data.entries) == "table" and data.entries or {}) do
                local clean = B.clean(e)
                if clean then entries[#entries + 1] = clean end
            end
            if type(data.settings) == "table" then settings = data.settings end
            self.entries, self.settings = entries, settings
            return true
        end
        if firstLoad then
            local backup = self.path .. ".bak"
            if fs.exists(backup) then fs.delete(backup) end
            fs.copy(self.path, backup)
            self.notice = "Address book was unreadable, saved a copy as " .. backup
        else
            return false
        end
    end

    -- new book: import the Stargate Monitor cartouche if it is next to us
    if fs.exists("1_cartouche.lua") then
        local ok, list = pcall(dofile, "1_cartouche.lua")
        if ok and type(list) == "table" then
            for _, e in ipairs(list) do
                local clean = B.clean(e)
                if clean and clean.address then entries[#entries + 1] = clean end
            end
            self.notice = "Imported " .. #entries .. " addresses from 1_cartouche.lua"
        end
    end
    if #entries == 0 then
        for _, e in ipairs(B.DEFAULTS) do entries[#entries + 1] = B.clean(e) end
    end
    self.entries, self.settings = entries, settings
    self:save()
    return true
end

function B:save()
    local f = fs.open(self.path, "w")
    if not f then return false end
    f.write(textutils.serialize({ entries = self.entries, settings = self.settings }))
    f.close()
    return true
end

function B:find(address)
    if not address then return nil end
    for _, e in ipairs(self.entries) do
        if e.address and A.same(e.address, address) then return e end
    end
end

-- name of a gate address if it is in the book, otherwise the formatted address
function B:describe(address)
    if not address then return nil end
    local e = self:find(address)
    return e and e.name or A.format(address)
end

function B:groups()
    local seen, out = {}, {}
    for _, e in ipairs(self.entries) do
        local g = e.group or "Other"
        if not seen[g] then
            seen[g] = true
            out[#out + 1] = g
        end
    end
    return out
end

function B:setting(key, default)
    local v = self.settings[key]
    if v == nil then return default end
    return v
end

function B:set(key, value)
    self.settings[key] = value
    self:save()
end

return B
