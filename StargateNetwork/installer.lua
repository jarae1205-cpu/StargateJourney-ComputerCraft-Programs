--
--   StargateNetwork installer
--
-- Usage: installer [branch]
--

local branch = ({ ... })[1] or "main"
local URL = "https://raw.githubusercontent.com/jarae1205-cpu/StargateJourney-ComputerCraft-Programs/"
    .. branch .. "/StargateNetwork/sgnet.lua"

print("StargateNetwork installer")
if not http then
    printError("The HTTP API is disabled in the ComputerCraft config.")
    return
end

print("Downloading sgnet.lua (" .. branch .. ")...")
local response, err = http.get(URL)
if not response then
    printError("Download failed: " .. tostring(err))
    print("Is raw.githubusercontent.com allowed in the config?")
    return
end
local code = response.readAll()
response.close()

local f = fs.open("sgnet.lua", "w")
f.write(code)
f.close()
print("Saved sgnet.lua")

write("Start StargateNetwork when the computer boots? (y/n) ")
local answer = read()
if answer:lower():sub(1, 1) == "y" then
    if fs.exists("startup.lua") then
        printError("startup.lua already exists, not touching it.")
    else
        f = fs.open("startup.lua", "w")
        f.write('shell.run("sgnet.lua")')
        f.close()
        print("Created startup.lua")
    end
end

print("Done! Run: sgnet")
