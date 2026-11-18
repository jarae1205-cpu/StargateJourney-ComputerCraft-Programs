-- Installer for Stargate Hybrid Legacy (SGHL)
-- Usage: installer            (dialing computer)
--        installer remote     (pocket dialer)

local BASE = "https://raw.githubusercontent.com/jarae1205-cpu/StargateJourney-ComputerCraft-Programs/main/StargateHybridLegacy/"
local FILE = "sghl.lua"

local args = { ... }
local remote = args[1] == "remote"

if not http then
  printError("The HTTP API is disabled in the ComputerCraft config.")
  print("Copy " .. FILE .. " onto this computer by hand instead.")
  return
end

print("Downloading Stargate Hybrid Legacy...")
local response, err = http.get(BASE .. FILE)
if not response then
  printError("Download failed: " .. tostring(err))
  print("raw.githubusercontent.com must be allowed in the ComputerCraft config.")
  return
end
local body = response.readAll()
response.close()

local h = fs.open(FILE, "w")
h.write(body)
h.close()
print("Saved " .. FILE)

print("")
print("Start it automatically when the computer boots? (yes/no)")
local answer = read()
if answer == "yes" or answer == "y" then
  if fs.exists("startup.lua") then
    printError("startup.lua already exists, leaving it alone.")
  else
    local s = fs.open("startup.lua", "w")
    s.write(remote and 'shell.run("sghl", "remote")' or 'shell.run("sghl")')
    s.close()
    print("Created startup.lua")
  end
end

print("")
print("Done. Run: " .. (remote and "sghl remote" or "sghl"))
