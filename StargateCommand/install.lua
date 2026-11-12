--
--   Stargate Command installer
--
--   wget run https://raw.githubusercontent.com/jarae1205-cpu/StargateJourney-ComputerCraft-Programs/main/StargateCommand/install.lua
--
--   Downloads the Gate Room, the Network Hub, the Personal Dialer and the
--   shared sgc library into the current folder. Run it again to update; your
--   address book (dialer_addresses.db) is kept.
--
--   install                 download everything
--   install gateroom        ... and start the Gate Room when the computer boots
--   install hub             ... and start the Network Hub when the computer boots
--   install dialer          ... and start the Personal Dialer when the computer boots
--

local BASE = "https://raw.githubusercontent.com/jarae1205-cpu/StargateJourney-ComputerCraft-Programs/main/"

local FILES = {
    { "StargateCommand/gateroom.lua",    "gateroom.lua" },
    { "StargateCommand/hub.lua",         "hub.lua" },
    { "StargateCommand/sgc/address.lua", "sgc/address.lua" },
    { "StargateCommand/sgc/book.lua",    "sgc/book.lua" },
    { "StargateCommand/sgc/gate.lua",    "sgc/gate.lua" },
    { "StargateCommand/sgc/pixels.lua",  "sgc/pixels.lua" },
    { "StargateCommand/sgc/ring.lua",    "sgc/ring.lua" },
    { "StargateCommand/sgc/styles.lua",  "sgc/styles.lua" },
    { "StargateCommand/sgc/ui.lua",      "sgc/ui.lua" },
    { "PersonalDialer/dialer.lua",       "dialer.lua" },
}

local STARTUP = { gateroom = "gateroom", hub = "hub", dialer = "dialer" }

local args = { ... }
local dir = shell.dir()

if not http then
    printError("HTTP is disabled in the CC: Tweaked config, copy the files by hand.")
    return
end

local function download(url, path)
    local response, err = http.get(url, nil, true)
    if not response then return false, err end
    local data = response.readAll()
    response.close()
    local full = fs.combine(dir, path)
    local parent = fs.getDir(full)
    if parent ~= "" and not fs.exists(parent) then fs.makeDir(parent) end
    local f = fs.open(full, "wb")
    if not f then return false, "can't write " .. full end
    f.write(data)
    f.close()
    return true
end

print("Installing Stargate Command into /" .. dir)
local failed = 0
for _, file in ipairs(FILES) do
    write("  " .. file[2] .. " ")
    local ok, err = download(BASE .. file[1], file[2])
    if ok then
        term.setTextColor(colors.lime)
        print("ok")
    else
        term.setTextColor(colors.red)
        print("failed: " .. tostring(err))
        failed = failed + 1
    end
    term.setTextColor(colors.white)
end

if failed > 0 then
    printError(failed .. " file(s) failed, run the installer again.")
    return
end

local program = STARTUP[args[1] or ""]
if program then
    local f = fs.open("startup.lua", "w")
    f.write('shell.run("' .. fs.combine(dir, program) .. '")\n')
    f.close()
    print("startup.lua now starts " .. program .. ".")
end

print("")
print("Done. Programs:")
print("  gateroom   SGC style gate room on a monitor")
print("  hub        destination cards, tap to dial")
print("  dialer     address book dialer")
print("All three share dialer_addresses.db.")
