--
-- sgc.oc - runs the sgc library on OpenComputers (OpenOS)
--
-- The library was written for CC: Tweaked. This module gives it what it uses from there:
-- colors, peripheral (on top of components), fs, textutils, sleep, os.clock and os.day.
--
--   local OC = require("sgc.oc")
--   OC.install()        before requiring the other sgc modules
--   ...
--   OC.uninstall()      when the program ends (puts os.clock back)
--

local component = require("component")
local computer = require("computer")
local serialization = require("serialization")
local filesystem = require("filesystem")
local shell = require("shell")

local O = {}

O.COLORS = {
    white = 1, orange = 2, magenta = 4, lightBlue = 8, yellow = 16, lime = 32, pink = 64, gray = 128,
    lightGray = 256, cyan = 512, purple = 1024, blue = 2048, brown = 4096, green = 8192, red = 16384, black = 32768,
}

-- CC: Tweaked's default colours, by index 0-15 (colors.white is index 0)
O.PALETTE = {
    [0] = 0xF0F0F0, 0xF2B233, 0xE57FD8, 0x99B2F2, 0xDEDE6C, 0x7FCC19, 0xF2B2CC, 0x4C4C4C,
    0x999999, 0x4C99B2, 0xB266E5, 0x3366CC, 0x7F664C, 0x57A64E, 0xCC4C4C, 0x111111,
}

-- data files (dialer_addresses.db, iris_codes.db, gate_log.db) live in /home, whichever
-- directory the program was started from, the way CC keeps them at the computer's root
O.HOME = "/home"

local function resolve(path)
    path = tostring(path)
    if path:sub(1, 1) ~= "/" then path = O.HOME .. "/" .. path end
    return shell.resolve(path)
end

-- a component as a table of functions, like a CC peripheral
local names = setmetatable({}, { __mode = "k" })

function O.wrap(address)
    local p = {}
    for name in pairs(component.methods(address)) do
        p[name] = function(...) return component.invoke(address, name, ...) end
    end
    -- getters (JSG's stargateAddress, dialedAddress) are called the same way
    if component.fields then
        local ok, fields = pcall(component.fields, address)
        if ok and type(fields) == "table" then
            for name in pairs(fields) do
                if not p[name] then p[name] = function(...) return component.invoke(address, name, ...) end end
            end
        end
    end
    names[p] = address
    return p
end

local function fileHandle(f)
    return {
        readAll = function() return f:read("*a") end,
        readLine = function() return f:read("*l") end,
        write = function(s) f:write(s) end,
        writeLine = function(s) f:write(s, "\n") end,
        flush = function() f:flush() end,
        close = function() f:close() end,
    }
end

local saved = nil

function O.install()
    if saved then return end
    saved = { clock = os.clock }
    _G.colors = O.COLORS
    _G.colours = O.COLORS
    _G.sleep = os.sleep
    -- os.clock is processor time on OpenOS; the library wants seconds since start
    os.clock = computer.uptime
    -- OpenOS's os.time() is in-game seconds (a day is 86400); CC has os.day()
    if not os.day then
        os.day = function() return math.floor(os.time() / 86400) end
    end
    _G.fs = {
        exists = function(path) return filesystem.exists(resolve(path)) end,
        open = function(path, mode)
            local m = (mode == "r" or mode == "rb") and "r" or ((mode == "a" or mode == "ab") and "a" or "w")
            local f = io.open(resolve(path), m)
            return f and fileHandle(f) or nil
        end,
        delete = function(path) filesystem.remove(resolve(path)) end,
        copy = function(from, to) filesystem.copy(resolve(from), resolve(to)) end,
    }
    _G.textutils = {
        serialize = function(value) return serialization.serialize(value) end,
        unserialize = function(text) return serialization.unserialize(text) end,
    }
    _G.peripheral = {
        find = function(ptype, filter)
            for address in component.list(ptype, true) do
                local p = O.wrap(address)
                if not filter or filter(address, p) then return p end
            end
            return nil
        end,
        wrap = function(address)
            local ok, t = pcall(component.type, address)
            if not ok or not t then return nil end
            return O.wrap(address)
        end,
        getName = function(p) return names[p] end,
        getType = function(address)
            local ok, t = pcall(component.type, address)
            return ok and t or nil
        end,
        isPresent = function(address)
            local ok, t = pcall(component.type, address)
            return ok and t ~= nil
        end,
        getNames = function()
            local list = {}
            for address in component.list() do list[#list + 1] = address end
            return list
        end,
    }
end

function O.uninstall()
    if not saved then return end
    os.clock = saved.clock
    saved = nil
end

return O
