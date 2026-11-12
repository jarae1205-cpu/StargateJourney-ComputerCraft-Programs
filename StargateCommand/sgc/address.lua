--
-- sgc.address - gate addresses for every supported mod
--
--   numbers  Stargate Journey and Lantea: Stargates, e.g. { 26, 6, 14, 31, 11, 29 }
--            (6 to 8 symbols, 1-38; the point of origin 0 is added when dialing)
--   letters  SGCraft: a string of 7 or 9 letters/digits, e.g. "WLDQDQBMT"
--   names    Just Stargate Mod: symbol names, e.g. { "Crater", "Virgo", "Bootes", ... }
--            (the point of origin is added when dialing)
--

local A = {}

local function trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function isOriginName(s)
    s = trim(s):lower()
    -- Milky Way, Pegasus (JSG "Subido") and Universe (JSG "G17") points of origin
    return s == "point of origin" or s == "origin" or s == "poo" or s == "subido" or s == "g17"
end

-- "serpens caput" -> "Serpens Caput"
local function titleCase(s)
    return (trim(s):lower():gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end

-- "numbers", "letters", "names" or nil
function A.kind(address)
    if type(address) == "string" and #address > 0 then return "letters" end
    if type(address) == "table" and #address > 0 then
        return type(address[1]) == "string" and "names" or "numbers"
    end
    return nil
end

-- copy of an address without the trailing point of origin
function A.strip(address)
    if type(address) == "string" then return address end
    local out = {}
    if type(address) ~= "table" then return out end
    for i, s in ipairs(address) do out[i] = s end
    local last = out[#out]
    if last == 0 or (type(last) == "string" and isOriginName(last)) then out[#out] = nil end
    return out
end

function A.same(a, b)
    if type(a) == "string" or type(b) == "string" then
        return type(a) == "string" and type(b) == "string" and a ~= "" and a == b
    end
    a, b = A.strip(a), A.strip(b)
    if #a ~= #b or #a == 0 then return false end
    for i = 1, #a do
        local x, y = a[i], b[i]
        if type(x) == "string" and type(y) == "string" then
            if x:lower() ~= y:lower() then return false end
        elseif x ~= y then
            return false
        end
    end
    return true
end

function A.format(address)
    local kind = A.kind(address)
    if kind == "letters" then
        if #address <= 4 then return address end
        return address:sub(1, 4) .. "-" .. address:sub(5, 7) .. (#address > 7 and ("-" .. address:sub(8)) or "")
    elseif kind == "names" then
        return table.concat(address, ", ")
    elseif kind == "numbers" then
        return "-" .. table.concat(address, "-") .. "-"
    end
    return "-"
end

-- the symbols as a list (numbers, letters or names)
function A.symbols(address)
    local out = {}
    if type(address) == "string" then
        for c in address:gmatch(".") do out[#out + 1] = c end
    elseif type(address) == "table" then
        for i, s in ipairs(A.strip(address)) do out[i] = s end
    end
    return out
end

-- accepts
--   "-26-6-14-31-11-29-", "26 6 14 31 11 29", "26,6,14,..."   numbers
--   "WLDQ-DQB-MT", "wldqdqbmt"                                 letters (SGCraft)
--   "Crater, Virgo, Bootes, Centaurus, Libra, Serpens Caput"   names (JSG), comma separated
function A.parse(text)
    text = tostring(text or "")
    if text:find("%a") and text:find(",") then
        local names, seen = {}, {}
        for part in (text .. ","):gmatch("([^,]*),") do
            local name = titleCase(part)
            if name ~= "" and not isOriginName(name) then
                if seen[name:lower()] then return nil, name .. " is used twice" end
                seen[name:lower()] = true
                names[#names + 1] = name
            end
        end
        if #names < 6 or #names > 8 then return nil, "Address needs 6 to 8 symbol names (without the point of origin)" end
        return names
    end
    if text:find("%a") then
        local s = text:upper():gsub("[^A-Z0-9]", "")
        if #s ~= 7 and #s ~= 9 then
            return nil, "SGCraft addresses have 7 or 9 letters/digits; JSG symbol names need commas"
        end
        return s
    end
    local address = {}
    for num in text:gmatch("%d+") do
        address[#address + 1] = tonumber(num)
    end
    if address[#address] == 0 then
        address[#address] = nil
    end
    if #address < 6 or #address > 8 then
        return nil, "Address needs 6 to 8 symbols (without the point of origin)"
    end
    local seen = {}
    for _, s in ipairs(address) do
        if s < 1 or s > 38 then return nil, "Symbol " .. s .. " is out of range (1-38)" end
        if seen[s] then return nil, "Symbol " .. s .. " is used twice" end
        seen[s] = true
    end
    return address
end

-- reads an address from a gate event / method result / saved entry
function A.fromValue(v)
    if type(v) == "table" then
        local out = {}
        local names = false
        for _, s in ipairs(v) do
            if type(s) == "string" and s:find("%a") then
                names = true
                out[#out + 1] = trim(s)
            elseif type(s) == "number" and not names then
                out[#out + 1] = s
            end
        end
        out = A.strip(out)
        return #out > 0 and out or nil
    elseif type(v) == "string" then
        local s = v:upper():gsub("[^A-Z0-9]", "")
        return #s > 0 and s or nil
    end
    return nil
end

-- which mods dial which address format
A.MOD_KIND = { sgjourney = "numbers", lantea = "numbers", sgcraft = "letters", jsg = "names" }
A.KIND_LABEL = { numbers = "a Stargate Journey / Lantea", letters = "an SGCraft", names = "a Just Stargate Mod" }

-- true if a gate of that mod can dial the address; otherwise false and a message
function A.dialableBy(address, mod)
    local kind = A.kind(address)
    if not kind then return false, "No address" end
    if A.MOD_KIND[mod] == kind then return true end
    return false, "That is " .. A.KIND_LABEL[kind] .. " address, this gate needs " .. (A.KIND_LABEL[A.MOD_KIND[mod]] or "a different") .. " one"
end

A.isOriginName = isOriginName
return A
