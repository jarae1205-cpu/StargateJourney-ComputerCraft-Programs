--
-- sgc.ui - drawing helpers and touch/click areas
--

local U = {}
U.__index = U

function U.new(t)
    return setmetatable({ t = t, hits = {} }, U)
end

function U:clearHits() self.hits = {} end

function U:write(x, y, s, fg, bg)
    local t = self.t
    t.setCursorPos(x, y)
    if fg then t.setTextColor(fg) end
    if bg then t.setBackgroundColor(bg) end
    t.write(s)
end

function U:fill(x, y, w, h, bg)
    if w <= 0 or h <= 0 then return end
    local t = self.t
    local line = string.rep(" ", w)
    t.setBackgroundColor(bg)
    for yy = y, y + h - 1 do
        t.setCursorPos(x, yy)
        t.write(line)
    end
end

function U:center(x, y, w, s, fg, bg)
    s = U.fit(s, w)
    self:write(x + math.floor((w - #s) / 2), y, s, fg, bg)
end

function U:hit(x1, y1, x2, y2, fn)
    self.hits[#self.hits + 1] = { x1, y1, x2, y2, fn }
end

function U:button(x, y, label, fg, bg, fn)
    self:write(x, y, label, fg, bg)
    if fn then self:hit(x, y, x + #label - 1, y, fn) end
    return x + #label
end

-- a two-line high button
function U:bigButton(x, y, w, label, fg, bg, fn)
    self:fill(x, y, w, 2, bg)
    self:center(x, y, w, label, fg, bg)
    if fn then self:hit(x, y, x + w - 1, y + 1, fn) end
end

function U:click(x, y, button)
    for i = #self.hits, 1, -1 do
        local h = self.hits[i]
        if x >= h[1] and x <= h[3] and y >= h[2] and y <= h[4] then
            h[5](x, y, button)
            return true
        end
    end
    return false
end

function U.fit(s, width)
    s = tostring(s or "")
    if width <= 0 then return "" end
    if #s <= width then return s end
    if width <= 2 then return s:sub(1, width) end
    return s:sub(1, width - 2) .. ".."
end

function U.pad(s, width)
    s = U.fit(s, width)
    return s .. string.rep(" ", width - #s)
end

function U.wrap(text, width)
    local lines = {}
    for para in (tostring(text) .. "\n"):gmatch("(.-)\n") do
        local line = ""
        for word in para:gmatch("%S+") do
            if #line == 0 then
                line = word
            elseif #line + 1 + #word <= width then
                line = line .. " " .. word
            else
                lines[#lines + 1] = line
                line = word
            end
            while #line > width do
                lines[#lines + 1] = line:sub(1, width)
                line = line:sub(width + 1)
            end
        end
        lines[#lines + 1] = line
    end
    return lines
end

function U.energy(n)
    if type(n) ~= "number" then return "?" end
    if n >= 1e9 then return string.format("%.1fG", n / 1e9) end
    if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
    if n >= 1e3 then return string.format("%.1fk", n / 1e3) end
    return tostring(math.floor(n))
end

function U.duration(s)
    s = math.max(0, math.floor(s or 0))
    local floor = math.floor
    if s >= 3600 then return string.format("%d:%02d:%02d", floor(s / 3600), floor((s % 3600) / 60), s % 60) end
    return string.format("%02d:%02d", floor(s / 60), s % 60)
end

return U
