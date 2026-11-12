--
-- Installs gatedial, the idc program and the sgc library on OpenComputers (OpenOS).
-- Needs an internet card. In the shell:
--
--   wget -f https://raw.githubusercontent.com/jarae1205-cpu/StargateJourney-ComputerCraft-Programs/main/OpenComputers/install.lua /tmp/install.lua
--   /tmp/install.lua
--
-- Run it again to update. The address book, iris codes and gate log in /home are kept.
--

local component = require("component")
local filesystem = require("filesystem")

local BASE = "https://raw.githubusercontent.com/jarae1205-cpu/StargateJourney-ComputerCraft-Programs/main/"

local FILES = {
    { "OpenComputers/gatedial.lua",      "/home/bin/gatedial.lua" },
    { "StargateCommand/idc.lua",         "/home/bin/idc.lua" },
    { "StargateCommand/sgc/oc.lua",      "/home/lib/sgc/oc.lua" },
    { "StargateCommand/sgc/address.lua", "/home/lib/sgc/address.lua" },
    { "StargateCommand/sgc/book.lua",    "/home/lib/sgc/book.lua" },
    { "StargateCommand/sgc/calllog.lua", "/home/lib/sgc/calllog.lua" },
    { "StargateCommand/sgc/gate.lua",    "/home/lib/sgc/gate.lua" },
    { "StargateCommand/sgc/idc.lua",     "/home/lib/sgc/idc.lua" },
    { "StargateCommand/sgc/jsg112.lua",  "/home/lib/sgc/jsg112.lua" },
    { "StargateCommand/sgc/pixels.lua",  "/home/lib/sgc/pixels.lua" },
    { "StargateCommand/sgc/ring.lua",    "/home/lib/sgc/ring.lua" },
    { "StargateCommand/sgc/styles.lua",  "/home/lib/sgc/styles.lua" },
}

if not component.isAvailable("internet") then
    io.stderr:write("The files come from GitHub: put an internet card in this computer.\n")
    return
end
local internet = require("internet")

local function download(url)
    local ok, handle = pcall(internet.request, url)
    if not ok or not handle then return nil, tostring(handle) end
    local parts = {}
    local read, why = pcall(function()
        for chunk in handle do parts[#parts + 1] = chunk end
    end)
    if not read then return nil, tostring(why) end
    local data = table.concat(parts)
    if data == "" or data:sub(1, 3) == "404" then return nil, "not found" end
    return data
end

-- everything is downloaded first, so a failed update leaves the old programs working
local downloaded, failed = {}, 0
for _, file in ipairs(FILES) do
    io.write("  " .. file[1] .. " ")
    local data, why = download(BASE .. file[1])
    if data then
        downloaded[#downloaded + 1] = { file[2], data }
        print("ok")
    else
        print("FAILED (" .. why .. ")")
        failed = failed + 1
    end
end
if failed > 0 then
    io.stderr:write(failed .. " files did not download, so nothing was changed. Try again.\n")
    return
end

filesystem.makeDirectory("/home/bin")
filesystem.makeDirectory("/home/lib/sgc")
for _, file in ipairs(downloaded) do
    local f, why = io.open(file[1], "w")
    if not f then
        io.stderr:write("Could not write " .. file[1] .. ": " .. tostring(why) .. "\n")
        return
    end
    f:write(file[2])
    f:close()
end
print("Installed. Run gatedial next to a stargate (SGCraft through an adapter, or a JSG gate base).")
print("Trusted iris codes: idc add <code> [name]")
