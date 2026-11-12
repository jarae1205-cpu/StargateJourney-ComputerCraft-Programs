--
-- sgc.address - gate addresses for Stargate Journey and SGCraft
--
-- Stargate Journey addresses are tables of numbers, e.g. { 26, 6, 14, 31, 11, 29 }
-- (6 to 8 symbols, 1-38, the point of origin 0 is added when dialing).
-- SGCraft addresses are strings of 7 or 9 letters/digits, e.g. "WLDQDQBMT".
--

local A = {}

-- "sgjourney", "sgcraft" or nil
function A.kind(address)
    if type(address) == "table" and #address > 0 then return "sgjourney" end
    if type(address) == "string" and #address > 0 then return "sgcraft" end
    return nil
end

-- copy of a Stargate Journey address without the trailing point of origin
function A.strip(address)
    if type(address) == "string" then return address end
    local out = {}
    if type(address) ~= "table" then return out end
    for i, s in ipairs(address) do out[i] = s end
    if out[#out] == 0 then out[#out] = nil end
    return out
end

function A.same(a, b)
    if type(a) == "string" or type(b) == "string" then
        return type(a) == "string" and type(b) == "string" and a ~= "" and a == b
    end
    a, b = A.strip(a), A.strip(b)
    if #a ~= #b or #a == 0 then return false end
    for i = 1, #a do
        if a[i] ~= b[i] then return false end
    end
    return true
end

function A.format(address)
    if type(address) == "string" then
        if #address == 0 then return "-" end
        if #address <= 4 then return address end
        return address:sub(1, 4) .. "-" .. address:sub(5, 7) .. (#address > 7 and ("-" .. address:sub(8)) or "")
    end
    if type(address) ~= "table" or #address == 0 then return "-" end
    return "-" .. table.concat(address, "-") .. "-"
end

-- the symbols as a list (numbers, or one-letter strings for SGCraft)
function A.symbols(address)
    local out = {}
    if type(address) == "string" then
        for c in address:gmatch(".") do out[#out + 1] = c end
    elseif type(address) == "table" then
        for i, s in ipairs(A.strip(address)) do out[i] = s end
    end
    return out
end

-- accepts "-26-6-14-31-11-29-", "26 6 14 31 11 29", "26,6,14,..." (Stargate Journey)
-- or "WLDQ-DQB-MT", "wldqdqbmt" (SGCraft)
function A.parse(text)
    text = tostring(text or "")
    if text:find("%a") then
        local s = text:upper():gsub("[^A-Z0-9]", "")
        if #s ~= 7 and #s ~= 9 then
            return nil, "SGCraft addresses have 7 or 9 letters/digits"
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

-- reads an address from a gate event / method result (table or string)
function A.fromValue(v)
    if type(v) == "table" then
        local out = {}
        for _, s in ipairs(v) do
            if type(s) == "number" then out[#out + 1] = s end
        end
        out = A.strip(out)
        return #out > 0 and out or nil
    elseif type(v) == "string" then
        local s = v:upper():gsub("[^A-Z0-9]", "")
        return #s > 0 and s or nil
    end
    return nil
end

return A
