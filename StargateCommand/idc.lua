--
-- idc - iris codes and the gate log
--
--   idc                     list the trusted iris codes
--   idc add <code> [name]   trust a code, e.g.  idc add 1234 SG-1
--   idc remove <code>       stop trusting a code
--   idc log [count]         show the gate log (newest first)
--
-- The Gate Room opens the iris when the gate that dialed in sends a trusted code.
-- To send your own code when you dial out, give the address book entry a code
-- in the Personal Dialer (its edit form has an "Iris code" field).
--

local IDC = require("sgc.idc")
local CallLog = require("sgc.calllog")

local args = { ... }
local cmd = args[1] and args[1]:lower()

local function list()
    local codes = IDC.load()
    if #codes == 0 then
        print("No trusted iris codes. Add one with: idc add <code> [name]")
        return
    end
    print("Trusted iris codes:")
    for _, e in ipairs(codes) do
        print(string.format("  %-16s %s", e.code, e.name))
    end
end

if not cmd or cmd == "list" then
    list()
elseif cmd == "add" then
    local code = IDC.clean(args[2])
    if not code then
        printError("A code is 1 to 16 letters, digits or dashes: idc add <code> [name]")
        return
    end
    local name = table.concat(args, " ", 3)
    local codes = IDC.load()
    IDC.add(codes, code, name ~= "" and name or nil)
    IDC.save(codes)
    print("Trusted " .. code .. (name ~= "" and (" (" .. name .. ")") or ""))
elseif cmd == "remove" or cmd == "rm" or cmd == "delete" then
    local codes = IDC.load()
    if IDC.remove(codes, args[2]) then
        IDC.save(codes)
        print("Removed " .. IDC.clean(args[2]))
    else
        printError("No trusted code " .. tostring(args[2]))
    end
elseif cmd == "log" then
    local count = tonumber(args[2]) or 20
    local log = CallLog.open()
    if #log.entries == 0 then
        print("The gate log is empty")
        return
    end
    for i = 1, math.min(count, #log.entries) do
        local when, label, text = CallLog.describe(log.entries[i])
        print(string.format("%-14s %-5s %s", when, label, text))
    end
else
    print("Usage:")
    print("  idc                     list trusted codes")
    print("  idc add <code> [name]   trust a code")
    print("  idc remove <code>       stop trusting it")
    print("  idc log [count]         show the gate log")
end
