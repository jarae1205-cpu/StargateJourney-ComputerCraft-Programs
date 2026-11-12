--
-- sgc.idc - iris codes (IDC)
--
-- Like the SGC's GDO: the dialing side sends a code through the wormhole, and the
-- gate room on the other side opens its iris if the code is on its trusted list.
--
-- Messages sent through the gate:
--   "IDC:1234"            a code
--   "IDC:ACCEPTED SG-1"   the answer when the code is trusted (with the name it is saved under)
--   "IDC:REJECTED"        the answer when it is not
--
-- The trusted list lives in iris_codes.db: { { code = "1234", name = "SG-1" }, ... }
--

local I = {}

I.FILE = "iris_codes.db"
I.PREFIX = "IDC:"

-- a code is 1-16 letters, digits or dashes; nil if it is not one
function I.clean(code)
    if code == nil then return nil end
    code = tostring(code):gsub("%s", ""):upper()
    if code == "" or #code > 16 or code:find("[^%w%-]") then return nil end
    return code
end

function I.message(code)
    return I.PREFIX .. code
end

-- reads a message that came through the gate:
--   "code", "1234"  |  "accepted", "SG-1" (name or nil)  |  "rejected"  |  nil (not an IDC message)
function I.parse(text)
    if type(text) ~= "string" then return nil end
    local body = text:match("^%s*[Ii][Dd][Cc]%s*[:%s]%s*(.-)%s*$")
    if not body then return nil end
    local word, rest = body:match("^(%S+)%s*(.-)$")
    word = word and word:upper()
    if word == "ACCEPTED" then return "accepted", rest ~= "" and rest or nil end
    if word == "REJECTED" then return "rejected" end
    local code = I.clean(body)
    if code then return "code", code end
    return nil
end

function I.load(path)
    path = path or I.FILE
    local list = {}
    if fs.exists(path) then
        local f = fs.open(path, "r")
        local data = f and textutils.unserialize(f.readAll())
        if f then f.close() end
        for _, e in ipairs(type(data) == "table" and data or {}) do
            local code = type(e) == "table" and I.clean(e.code)
            if code then list[#list + 1] = { code = code, name = tostring(e.name or "") } end
        end
    end
    return list
end

function I.save(list, path)
    local f = fs.open(path or I.FILE, "w")
    if not f then return false end
    f.write(textutils.serialize(list))
    f.close()
    return true
end

-- the trusted entry for a code, or nil
function I.check(list, code)
    code = I.clean(code)
    if not code then return nil end
    for _, e in ipairs(list) do
        if e.code == code then return e end
    end
end

-- adds or renames a code; returns the entry
function I.add(list, code, name)
    code = I.clean(code)
    if not code then return nil end
    local e = I.check(list, code)
    if e then
        e.name = name or e.name
    else
        e = { code = code, name = name or "" }
        list[#list + 1] = e
    end
    return e
end

function I.remove(list, code)
    code = I.clean(code)
    for i, e in ipairs(list) do
        if e.code == code then
            table.remove(list, i)
            return true
        end
    end
    return false
end

return I
