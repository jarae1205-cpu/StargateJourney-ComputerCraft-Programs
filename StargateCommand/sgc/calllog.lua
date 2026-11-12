--
-- sgc.calllog - a log of what went through the gate
--
-- Kept in gate_log.db, newest first. Each entry:
--   { kind = "in" | "out" | "fail" | "closed" | "traveler" | "code",
--     day = 12, time = "14:05",      -- in-game day and time
--     address = {...} or nil, name = "Abydos" or nil, text = "..." or nil, seconds = 75 or nil }
--

local A = require("sgc.address")

local L = {}
L.__index = L

L.FILE = "gate_log.db"
L.MAX = 200

L.LABELS = {
    ["in"] = "IN", out = "OUT", fail = "FAIL", closed = "CLOSE", traveler = "TRAV", code = "IDC",
}

function L.open(path, max)
    local self = setmetatable({ path = path or L.FILE, max = max or L.MAX, entries = {} }, L)
    if fs.exists(self.path) then
        local f = fs.open(self.path, "r")
        local data = f and textutils.unserialize(f.readAll())
        if f then f.close() end
        if type(data) == "table" then
            for _, e in ipairs(data) do
                if type(e) == "table" and L.LABELS[e.kind] then self.entries[#self.entries + 1] = e end
            end
        end
    end
    return self
end

function L:save()
    local f = fs.open(self.path, "w")
    if not f then return false end
    f.write(textutils.serialize(self.entries))
    f.close()
    return true
end

function L:add(e)
    e.day = os.day()
    local t = os.time()
    -- CC: Tweaked gives the hour of the day; OpenOS gives in-game seconds
    if t > 24 then t = (t % 86400) / 3600 end
    e.time = string.format("%02d:%02d", math.floor(t), math.floor((t % 1) * 60))
    if e.address then e.address = A.fromValue(e.address) end
    table.insert(self.entries, 1, e)
    while #self.entries > self.max do table.remove(self.entries) end
    self:save()
    return e
end

local function duration(s)
    s = math.floor(s + 0.5)
    if s < 60 then return s .. "s" end
    return math.floor(s / 60) .. "m" .. string.format("%02d", s % 60) .. "s"
end

-- "Day 12 14:05", "IN", "Abydos -26-6-14-31-11-29-  open 2m05s"
function L.describe(e)
    local when = "Day " .. tostring(e.day or "?") .. " " .. tostring(e.time or "")
    local parts = {}
    if e.name then parts[#parts + 1] = e.name end
    if e.address and not (e.name and e.name == A.format(e.address)) then parts[#parts + 1] = A.format(e.address) end
    if e.text then parts[#parts + 1] = e.text end
    if e.seconds then parts[#parts + 1] = "open " .. duration(e.seconds) end
    -- some mods do not say which gate dialed in
    if #parts == 0 and e.kind == "in" then parts[1] = "Unknown gate" end
    return when, L.LABELS[e.kind] or "?", table.concat(parts, "  ")
end

return L
